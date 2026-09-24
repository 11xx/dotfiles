package Gitolite::Triggers::HubLock;
use strict;
use warnings;
use Fcntl qw(:flock :DEFAULT F_SETFD FD_CLOEXEC);

my $held;
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
    fcntl($handle, F_SETFD, FD_CLOEXEC)
        or die "cannot make Git hub lock close on exec\n";
    my @file_stat = stat($handle);
    die "unsafe Git hub lock file\n"
        unless @file_stat && -f _ && $file_stat[4] == 0
        && $file_stat[5] == $gid && ($file_stat[2] & 07777) == 0660;
    flock($handle, LOCK_EX) or die "cannot lock Git hub\n";
    $held = $handle;
}

sub post_git {
    close($held) if $held;
    undef $held;
}

1;
