package Virtualmin::Config::Plugin::AWStats;
use strict;
use warnings;
no warnings qw(once);
use parent 'Virtualmin::Config::Plugin';
use Time::HiRes qw( sleep );

our $config_directory;
our (%gconfig, %miniserv);
our $trust_unknown_referers = 1;

sub new {
  my ($class, %args) = @_;

  # inherit from Plugin
  my $self = $class->SUPER::new(name => 'AWStats', %args);

  return $self;
}

# actions method performs whatever configuration is needed for this
# plugin. XXX Needs to make a backup so changes can be reverted.
sub actions {
  my $self = shift;

  use Cwd;
  my $cwd  = getcwd();
  my $root = $self->root();
  chdir($root);
  $0 = "$root/virtual-server/config-system.pl";
  push(@INC, $root);
  eval 'use WebminCore';    ## no critic
  init_config();

  $self->spin();
  sleep 0.2;                # XXX Pause to allow spin to start.
  eval {
    # Remove cronjobs for awstats on Debian/Ubuntu
    foreign_require("cron");
    my @jobs = cron::list_cron_jobs();
    my @dis  = grep {
      $_->{'command'} =~ /\/usr\/share\/awstats\/tools\/(update|buildstatic).sh/
        && $_->{'active'}
    } @jobs;
    if (@dis) {
      foreach my $job (@dis) {
        $job->{'active'} = 0;
        cron::change_cron_job($job);
      }
    }

    # Comment out cron job for awstats on CentOS/RHEL
    my $file = '/etc/cron.hourly/awstats';
    if (-r $file) {
      my $lref = read_file_lines($file);
      foreach my $l (@$lref) {
        if ($l !~ /^\s*#/) {
          $l = "#" . $l;
        }
      }
      flush_file_lines($file);
    }
    $self->done(1);    # OK!
  };
  if ($@) {
    $self->done(0);
  }
}

1;
