package Gitolite::Triggers::HubLock;
use strict;
use warnings;
use Fcntl qw(:flock :DEFAULT F_GETFD F_SETFD FD_CLOEXEC);

my $held;
my $config_slot;
my $directory = '/var/lib/agentgit-lock';
my $path = "$directory/receive.lock";

sub pre_git {
    my ($section, $repo, $user, $access, $ref, $verb) = @_;
    return unless $verb eq 'git-receive-pack';
    my ($gid) = split /\s+/, $);
    my @directory_stat = lstat($directory);
    die "unsafe Git hub lock directory\n"
        unless @directory_stat && -d _ && $directory_stat[4] == 0
        && $directory_stat[5] == $gid && ($directory_stat[2] & 07777) == 0750;
    sysopen(my $handle, $path, O_RDWR | O_NOFOLLOW)
        or die "cannot open Git hub lock\n";
    my $flags = fcntl($handle, F_GETFD, 0);
    die "cannot inspect Git hub lock descriptor\n" unless defined $flags;
    fcntl($handle, F_SETFD, $flags & ~FD_CLOEXEC)
        or die "cannot pass Git hub lock to receive-pack\n";
    my @file_stat = stat($handle);
    die "unsafe Git hub lock file\n"
        unless @file_stat && -f _ && $file_stat[4] == 0
        && $file_stat[5] == $gid && ($file_stat[2] & 07777) == 0660;
    flock($handle, LOCK_EX) or die "cannot lock Git hub\n";
    $held = $handle;
    my $count = $ENV{GIT_CONFIG_COUNT} // 0;
    die "invalid Git config count\n" unless $count =~ /^\d+$/ && $count < 32;
    $config_slot = $count;
    $ENV{"GIT_CONFIG_KEY_$count"} = 'core.hooksPath';
    $ENV{"GIT_CONFIG_VALUE_$count"} = '/etc/git-hub/hooks';
    $ENV{GIT_CONFIG_COUNT} = $count + 1;
    $ENV{GAK_HUB_CONFIG_BASE} = $count;
    $ENV{GAK_HUB_LOCK_FD} = fileno($handle);
}

sub post_git {
    close($held) if $held;
    undef $held;
    if (defined $config_slot) {
        $ENV{GIT_CONFIG_COUNT} = $config_slot;
        delete $ENV{"GIT_CONFIG_KEY_$config_slot"};
        delete $ENV{"GIT_CONFIG_VALUE_$config_slot"};
        undef $config_slot;
    }
    delete $ENV{GAK_HUB_CONFIG_BASE};
    delete $ENV{GAK_HUB_LOCK_FD};
}

1;
