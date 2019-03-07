require 'spec_helper'

describe MarcToArgot do
  include Util::TrajectRunTest
  let(:b1082803argot) { run_traject_json('unc', 'b1082803') }
  let(:b1246383argot) { run_traject_json('unc', 'b1246383') }
  let(:b1319986argot) { run_traject_json('unc', 'b1319986') }
  let(:cat_date) { run_traject_json('unc', 'cat_date') }
  let(:cat_date2) { run_traject_json('unc', 'cat_date2') }
  let(:ercn) { run_traject_json('unc', 'eres_callno') }
  let(:ercn2) { run_traject_json('unc', 'eres_callno2') }
  let(:ercn3) { run_traject_json('unc', 'eres_callno3') }
  
  it '(UNC) creates shelfkey' do
    expect(ercn['shelfkey']).to(
      eq('lc:ML.3556.B57.2018')
    )
    expect(ercn2['shelfkey']).to(
      eq('lc:HS.0537.N8')
    )
    expect(ercn3['shelfkey']).to(
      eq(nil)
    )
  end

  it '(UNC) set lcc_callnum_classification from bib' do
    expect(ercn['lcc_callnum_classification']).to(
      eq([
           "M - Music",
           "M - Music|ML1 - ML3930 Literature on music",
           "M - Music|ML1 - ML3930 Literature on music|ML159 - ML3775 History and criticism",
           "M - Music|ML1 - ML3930 Literature on music|ML159 - ML3775 History and criticism|ML3544 - ML3775 National music"
  ])
    )
  end
  
  it '(UNC) does not set virtual collection from 919$a' do
    expect(b1082803argot['virtual_collection']).to(
      eq(nil)
    )
  end

  it '(UNC) sets virtual collection from 919$t' do
    expect(b1246383argot['virtual_collection']).to(
      eq(['testcoll'])
    )
  end

  it '(UNC) sets virtual collection from repeated 919$t' do
    expect(b1319986argot['virtual_collection']).to(
      eq(['testcoll', 'anothercoll'])
    )
  end

  it '(UNC) sets date_cataloged' do
    expect(cat_date['date_cataloged']).to(
      eq(['2004-10-01T04:00:00Z'])
    )
  end

    it '(UNC) sets date_cataloged' do
    expect(cat_date2['date_cataloged']).to(
      eq(['2004-10-01T04:00:00Z'])
    )
  end
end
