{ maintainers, ...}:
with maintainers;
[
  {
    description = "Bundix ";
    paths = [ "pkgs/development/ruby-modules/bundix/*" ];
    maintainers = [ manveru ];
  }
]
