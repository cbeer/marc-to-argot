################################################
# Primary ID
######
to_field 'id', extract_marc(settings['specs'][:id], first: true) do |rec, acc|
  acc.collect! {|s| "#{s}"}
end

################################################
# Local ID
######

to_field 'local_id' do |rec, acc, context|
  local_id = {
    value: context.output_hash['id'].first,
    other: []
  }

  acc << local_id
end


################################################
# Institutiuon
######
to_field 'institution', literal('duke')

################################################
# Catalog Date
######

################################################
# Items
######
item_map = {
  p: { key: 'barcode' },
  n: { key: 'copy_number' },
  b: { key: 'library' },
  z: { key: 'note' },
  h: { key: 'call_number' },
  o: { key: 'status_code' },
  q: { key: 'process_state' },
  x: { key: 'date_due' },
  c: { key: 'shelving_location' },
  r: { key: 'type' },
  d: { key: 'call_number_scheme' }
}

def is_available?(items)
  items.any? { |i| i['status'].downcase.start_with?('available') rescue false }
end

def status_map
  @status_map ||= Traject::TranslationMap.new('duke/process_state')
end

def location_map
  @location_map ||= Traject::TranslationMap.new('duke/location_default_state')
end

def select_fields(rec, field_tag)
  rec.fields.select { |f| f.tag == field_tag }
end

def select_indicator2(rec, field_tag)
  select_fields(rec, field_tag).map { |field| field.indicator2 }
end

def find_subfield(rec, field_tag, subfield_code)
  select_fields(rec, field_tag).map do |field|
    field.subfields.find do |sf|
      sf.code == subfield_code
    end
  end
end

def subfield_has_value?(rec, field_tag, subfield_code, subfield_value)
  find_subfield(rec, field_tag, subfield_code).any? do |subfield|
    subfield.value == subfield_value
  end
end

def indicator_2_has_value?(rec, field_tag, indicator_value)
  select_indicator2(rec, field_tag).any? do |indicator|
    indicator == indicator_value
  end
end

def newspaper?(rec)
  subfield_has_value?(rec, '942', 'a', 'NP') ||
  (rec.leader.byteslice(7) == 's' && rec['008'].value.byteslice(21) == 'n')
end

def periodical?(rec)
  subfield_has_value?(rec, '942', 'a', 'JR') ||
  (rec.leader.byteslice(7) == 's' && rec['008'].value.byteslice(21) == 'p')
end

def serial?(rec)
  rec.leader.byteslice(7) == 's' ||
  subfield_has_value?(rec, '852', 'D', 'y') ||
  subfield_has_value?(rec, '942', 'a', 'AS')
end

def microform?(rec)
  subfield_has_value?(rec, '942', 'b', 'Microform')
end

def online?(rec)
  indicator_2_has_value?(rec, '856', '0') || indicator_2_has_value?(rec, '856', '1')
end

# TODO! Aleph makes it challenging to determine item status.
# This method duplicates the logic in aleph_to_endeca.pl
# that determines item status.
# Refactoring would help, but let's just get it working.
def item_status(rec, item)
  status_code = item['status_code'].to_s
  process_state = item['process_state'].to_s
  date_due = item['date_due'].to_s
  barcode = item['barcode'].to_s
  location_code = item['location_code'].to_s
  type = item['type'].to_s

  if !date_due.empty? && process_state != 'IT'
    status = 'Checked Out'
  elsif status_code == '00'
    status = 'Not Available'
  elsif status_code == 'P3'
    status = 'Ask at Reference Desk'
  elsif !process_state.empty?
    if process_state == 'NC'
      if newspaper?(rec) || periodical?(rec)
        if status_code == '03' || status_code == '08' || status_code == '02'
          status = 'Available - Library Use Only'
        else
          status = 'Available'
        end
      elsif microform?(rec)
        status = 'Ask at Circulation Desk'
      elsif barcode =~ /^B\d{6}/
        status = 'Ask at Circulation Desk'
      elsif location_map[location_code] == 'C' || location_map[location_code] == 'B'
        if status_code == '03' || status_code == '08' || status_code == '02'
          status = 'Available - Library Use Only'
        else
          status = 'Available'
        end
      elsif location_map[location_code] == 'N'
        status = 'Not Available'
      else
        if status_code == '03' || status_code == '08' || status_code == '02'
          status = 'Available - Library Use Only'
        else
          status = 'Ask at Circulation Desk'
        end
      end
    else
      if status_map[process_state]
        status = status_map[process_state]
      else
        status = 'UNKNOWN'
      end
    end
  elsif status_code == 'NI' || barcode =~ /^B\d{6}/
    if type == 'MAP' && status_code != 'NI'
      status = 'Available'
    elsif location_map[location_code] == 'A' || location_map[location_code] == 'B'
      if status_code == '03' || status_code == '08' || status_code == '02'
        status = 'Available - Library Use Only'
      else
        status = 'Available'
      end
    elsif location_map[location_code] == 'N'
      status = 'Not Available'
    else
      # NOTE! There's a whole set of additional elsif conditions in the Perl script
      # The result of which seems to be to set the status to 'Ask at Circulation Desk'
      # no matter whehther any of the condition is met.
      # It also sets %serieshash and $hasLocNote vars.
      # Skipping all that for now.
      # See line 5014 of aleph_to_endeca.pl
      status = 'Ask at Circulation Desk'
    end
  else
    if status_code == '03' || status_code == '08' || status_code == '02'
      status = 'Available - Library Use Only'
    else
      status = 'Available'
    end
  end

  if online?(rec) && status == 'Ask at Circulation Desk'
    status = 'Available'
    # NOTE! In the aleph_to_endeca.pl script (line 5082) there's some code
    #       here about switching the location to PEI. But let's pretend
    #       that's not happening for now.
  end

  status
end

to_field 'items' do |rec, acc, ctx|
  lcc_top = Set.new
  items = []

  Traject::MarcExtractor.cached('940', alternate_script: false).each_matching_line(rec) do |field, spec, extractor|
    item = {}

    field.subfields.each do |subfield|
      code = subfield.code.to_sym
      mapped = item_map.fetch(code, key: nil)[:key]
      item[mapped] = subfield.value unless mapped.nil?
    end

    item['status'] = item_status(rec, item)

    if item.fetch('call_number_scheme', '') == '0'
      item['call_number_scheme'] = 'LC'
      lcc_top.add(item['call_number'][0, 1])
    end

    items << item
    acc << item.to_json if item
  end
  ctx.output_hash['lcc_top'] = lcc_top.to_a
  ctx.output_hash['available'] = 'Available' if is_available?(items)

  map_call_numbers(ctx, items)
end

