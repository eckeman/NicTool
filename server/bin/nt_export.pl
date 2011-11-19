#!/usr/bin/perl

use strict;
use warnings;

use lib '.';
use lib 'lib';
use Data::Dumper;
use Getopt::Long;
use Params::Validate qw/:all/;
$Data::Dumper::Sortkeys=1;

use NicToolServer::Export;

# process command line options
Getopt::Long::GetOptions(
    'force'     => \my $force,
    'daemon'    => \my $daemon,
    'dsn=s'     => \my $dsn,
    'user=s'    => \my $db_user,
    'pass=s'    => \my $db_pass,
    'nsid=i'    => \my $nsid,
) or die "error parsing command line options";

if ( ! defined $dsn || ! defined $db_user || ! defined $db_pass ) {
    get_db_creds_from_nictoolserver_conf();
}

$dsn     = ask( "database DSN", default  =>
        'DBI:mysql:database=nictool;host=localhost;port=3306') if ! $dsn;
$db_user = ask( "database user", default => 'root' ) if ! $db_user;
$db_pass = ask( "database pass", password => 1 ) if ! $db_pass;

my $export = NicToolServer::Export->new( ns_id=>$nsid || 0 );
$export->get_dbh( dsn => $dsn, user => $db_user, pass => $db_pass,) 
    or die "database connection failed";

defined $nsid || get_nsid();

my $count = $export->get_modified_zones();
print "found $count zones\n";
my $r = $export->export();

sub get_nsid {
    my $nslist = $export->get_active_nameservers();
    printf( "\n%5s   %25s   %9s\n", 'nsid', 'name', 'format' );
    my $format = "%5.0f   %25s   %9s\n";
    foreach my $ns (@$nslist) {
        printf $format, $ns->{nt_nameserver_id}, $ns->{name}, $ns->{export_format};
    };
    die "\nERROR: missing nsid. Try this:
    
    $0 -nsid N\n";
};

sub ask {
    my $question = shift;
    my %p = validate( @_,
        {   default  => { type => SCALAR, optional => 1 },
            password => { type => BOOLEAN, optional => 1 },
        }
    );

    my $pass     = $p{password};
    my $default  = $p{default};
    my $response;

PROMPT:
    print "Please enter $question";
    print " [$default]" if defined $default;
    print ": ";
    system "stty -echo" if $pass;
    $response = <STDIN>;
    system "stty echo" if $pass;
    chomp $response;

    return $response if length $response  > 0;         # if they typed something, return it
    return $default if defined $default;   # return the default, if available
    return '';                             # return empty handed
}

sub get_db_creds_from_nictoolserver_conf {

    my $file = "lib/nictoolserver.conf";
    $file = "../server/lib/nictoolserver.conf" if ! -f $file;
    $file = "../lib/nictoolserver.conf" if ! -f $file;
    $file = "../nictoolserver.conf" if ! -f $file;
    $file = "nictoolserver.conf" if ! -f $file;
    return if ! -f $file;

    print "reading DB settings from $file\n";
    my $contents = `cat $file`;

    if ( ! $dsn ) {
        ($dsn) = $contents =~ m/['"](DBI:mysql.*?)["']/;
    };

    if ( ! $db_user ) {
        ($db_user) = $contents =~ m/db_user\s+=\s+'(\w+)'/;
    };

    if ( ! $db_pass ) {
        ($db_pass) = $contents =~ m/db_pass\s+=\s+'(.*)?'/;
    };
};
