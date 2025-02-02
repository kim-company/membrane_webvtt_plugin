# Used by "mix format"
[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  import_deps: [:membrane_core, :assert_value],
  # use this line length when updating expected value
  # whatever you prefer, default is 98
  line_length: 98
]
