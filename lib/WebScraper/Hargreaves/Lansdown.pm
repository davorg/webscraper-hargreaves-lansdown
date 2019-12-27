package WebScraper::Hargreaves::Lansdown;

use strict;
use warnings;
use feature 'say';

use Moose;
use LWP::UserAgent;
use HTTP::CookieJar::LWP;
use HTML::TableExtract;

has ua => (
  isa => 'LWP::UserAgent',
  is => 'ro',
  lazy_build => 1,
);

has $_ => (
  isa => 'Str',
  is => 'ro',
  required => 1,
) for qw[username password dob code];

sub _build_ua {
  return LWP::UserAgent->new(
    cookie_jar => HTTP::CookieJar::LWP->new,
  );
}

sub BUILD {
  my $self = shift;

  my $domain = 'https://online.hl.co.uk';
  my $path   = '/my-accounts/login-step-one';
  my $path2  = '/my-accounts/login-step-two';
  my $url    = "$domain$path";
  my $url2   = "$domain$path2";

  my $resp = $self->ua->get($url);
  my $page = $resp->content;

  my ($vt) = $page =~ m|<input type="hidden" name="hl_vt" value="(\d+)"/>|;

  $resp = $self->ua->post($url, {
    hl_vt => $vt,
    username => $self->username,
    'date-of-birth' => $self->dob,
  });

  if ($resp->is_redirect) {
    $url = "$domain$path";
  }

  $resp = $self->ua->get($url2);
  my @digits = $resp->content =~ /\sEnter the (\d).. digit/g;

  ($vt) = $page =~ m|<input type="hidden" name="hl_vt" value="(\d+)"/>|;

  my $post = {
    hl_vt => $vt,
    'online-password-verification' => $self->password,
  };

  for (0 .. 2) {
    my $input_name = 'secure-number[' . ($_ + 1) . ']';
    $post->{$input_name} = substr $self->code, $digits[$_] - 1, 1;
  }

  $resp = $self->ua->post($url2, $post);
}

sub overview {
  my $self = shift;

  my $logged_in_url = 'https://online.hl.co.uk/my-accounts/portfolio_overview';

  my $resp = $self->ua->get($logged_in_url);

  my $te = HTML::TableExtract->new(attribs => {
    class => 'hl-table portfolio-overview-table',
  });

  $te->parse($resp->content);

  foreach my $ts ($te->tables) {
    foreach my $row ($ts->rows) {
      say join(',', map { $_ = trim($_) } @$row);
    }
  }
}

sub trim {
  my ($str) = @_;

  $str =~ s/^\s+//;
  $str =~ s/\s+$//;

  return $str;
}

1;
