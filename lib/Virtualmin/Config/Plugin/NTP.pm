package Virtualmin::Config::Plugin::NTP;
use strict;
use warnings;
use 5.010;
use parent qw(Virtualmin::Config::Plugin);
use Time::HiRes qw( sleep );
my $log = Log::Log4perl->get_logger("virtualmin-config-system");

sub new {
  my $class = shift;

  # inherit from Plugin
  my $self = $class->SUPER::new(name => 'NTP');

  return $self;
}

# actions method performs whatever configuration is needed for this
# plugin. XXX Needs to make a backup so changes can be reverted.
sub actions {
  my $self = shift;
  my $clocksource;

  $self->spin();
  sleep 0.5;
  eval {    # try
    my $clockfile = "/sys/devices/system/clocksource/clocksource0/current_clocksource";
    if (-e $clockfile) {
      open(my $CLOCK, "<", $clockfile) or die "Couldn't open $clockfile: $!";
      $clocksource = do { local $/ = <$CLOCK> };
      close $CLOCK;
      chomp($clocksource);
    }
    if ($clocksource eq "kvm-clock") {
      $log->info("System clock source is kvm-clock, skipping NTP");
    }
    elsif (-x "/usr/sbin/ntpdate-debian") {
      $self->logsystem("ntpdate-debian");
    }
    elsif (-x "/usr/sbin/ntpdate") {
      $self->logsystem("ntpdate");
    }

    # If it's installed, and not kvm-clock, turn ntpd on.
    if (! $clocksource eq "kvm-clock" && init::action_status("ntpd")) {
      init::enable_at_boot("ntpd");
    }
    $self->done(1);      # OK!
  } or do {    # catch
    $self->done(0);    # Something failed
    $log->info("Something went wrong with NTP configuration");
    return;
  };
}

1;