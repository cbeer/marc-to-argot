# Marc to Argot transformer
 
## Requirements
[Traject](https://github.com/traject/traject)

Run command 
`traject -c argot.rb <marc-file>`

Optionally, add in an institutional config
`traject -c argot.rb -c config/<inst>.rb <marc-file>`

Pretty printed json, add:
`-s argot_writer.pretty_print=true`

Change the output file, add:
`-s output_file=<path/to/file>`

Note:
This was a first attempt at getting vernacular to play nice. Essentially,
the "create_vernacular_bag" makes a hash for all matching 880 fields.

When the fields are processed into a nested structure (i.e., create_title_object)
it reaches into that bag and pulls out the matching vernacular object, utilizing
subfield 6 to create a match.

