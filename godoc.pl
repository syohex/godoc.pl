#!/usr/bin/env perl
use strict;
use warnings;
use File::Spec ();
use File::Find qw(find);
use IPC::Open2;

my @builtins = qw(builtin unsafe);
my $pager = $ENV{PAGER} || "less";

my @go_directories;
push @go_directories, $ENV{GOROOT} if $ENV{GOROOT};
push @go_directories, $_ for split /:/, $ENV{GOPATH};

my %packages;
for my $dir (@go_directories) {
    my $pkgdir = File::Spec->catfile($dir, "pkg");
    next unless -d $pkgdir;

    find(sub {
        my $file = $File::Find::name;
        return unless -f $file;
        return unless $file =~ m/\.a$/;
        return if $file =~ m/Godeps/;
        return unless $file =~ m{$pkgdir/(?:(?:obj|tool)/)?[^/]+/(.+)\.a$};

        $packages{$1} = 1;
    }, @go_directories);
}

my $peco_input = join "\n", @builtins, (sort keys %packages);

my ($in_peco, $out_peco);
my $pid = IPC::Open2::open2($out_peco, $in_peco, "peco");
print {$in_peco} $peco_input;
my $package = <$out_peco>;
waitpid $pid, 0;

if ($package) {
    chomp $package;

    my $doc = do {
        local $/;
        open(my $godoc_fh, "-|", "godoc", $package) or die "Can't open godoc: $!";
        <$godoc_fh>;
    };

    open my $less_fh, "|-", $pager or die "Can't open $pager: $!";
    print {$less_fh} $doc;
    close $less_fh;
}
