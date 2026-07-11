package GitHook;

use 5.28.0;
use warnings;
use experimental "signatures";

use Exporter qw( import );

our @EXPORT_OK = qw( get_current_branch on_main ticket_re );

sub ticket_re () { qr/[A-Z]{2,8}-\d+/ }

sub get_current_branch () {
  my $branch = `git rev-parse --abbrev-ref HEAD 2>/dev/null` // "";
  chomp $branch;
  $branch
}

sub on_main () { get_current_branch eq "main" }

"There is a light that never goes out"
