# .coveralls.exs - ExCoveralls configuration
%{
  # Coverage threshold - fail if coverage is below this percentage
  minimum_coverage: 80,

  # Files to exclude from coverage
  skip_files: [
    "test/",
    "test/support/",
    "deps/",
    "priv/",
    "_build/",
    "assets/",
    # Generated files
    "lib/messaging_service_web/gettext.ex",
    "lib/messaging_service_web/telemetry.ex",
    "lib/messaging_service/mailer.ex",
    "lib/messaging_service.ex",
    "lib/messaging_service/repo.ex",
    "lib/messaging_service_web/gettext.ex",
    "lib/messaging_service_web/endpoint.ex"


  ],

  # Coverage output format
  coverage_options: [
    treat_no_relevant_lines_as_covered: true,
    minimum_coverage: 80,
    print_summary: true
  ],

  # HTML coverage report settings
  html_options: [
    extra_css: "",
    extra_js: "",
    output_dir: "cover/",
    template_path: "custom.html.eex"
  ]
}
