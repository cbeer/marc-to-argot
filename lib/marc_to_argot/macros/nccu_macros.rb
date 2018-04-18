module MarcToArgot
  module Macros
    # Macros and useful functions for NCCU records
    module NCCU
      include MarcToArgot::Macros::Shared

      # Sets the list of MARC org codes that are local.
      # Used by #subfield_5_present_with_local_code?
      def local_marc_org_codes
        %w[NcDurC NcDurCL]
      end
    end
  end
end
