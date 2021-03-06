use strict;
use warnings;
use Test::More import => ['!pass'];
use Dancer ':syntax';
use Dancer::Test;

plan skip_all => 'Test::TCP is needed to run this test'
    unless Dancer::ModuleLoader->load('Test::TCP');

use LWP::UserAgent;

plan tests => 26;

ok(Dancer::App->current->registry->is_empty,
    "registry is empty");
ok(Dancer::Plugin::Ajax::ajax( '/', sub { "ajax" } ), "ajax helper called");
ok(!Dancer::App->current->registry->is_empty,
    "registry is not empty");

Test::TCP::test_tcp(
    client => sub {
        my $port = shift;
        my $ua = LWP::UserAgent->new;

        my @queries = (
            { path => 'req', ajax => 1, success => 1, content => 1 },
            { path => 'req', ajax => 0, success => 0 },
            { path => 'foo', ajax => 1, success => 1, content => 'ajax' },
            { path => 'foo', ajax => 0, success => 1, content => 'not ajax' },
            { path => 'bar', ajax => 1, success => 1, content => 'ajax' },
            { path => 'bar', ajax => 0, success => 1, content => 'not ajax' },
        );

        foreach my $query (@queries) {
            ok my $request =
              HTTP::Request->new(
                GET => "http://127.0.0.1:$port/" . $query->{path} );

            $request->header( 'X-Requested-With' => 'XMLHttpRequest' )
              if ( $query->{ajax} == 1);

            ok my $res = $ua->request($request);

            if ( $query->{success} == 1) {
                ok $res->is_success;
                is $res->content, $query->{content};
            }
            else {
                ok !$res->is_success;
            }
        }
    },
    server => sub {
        my $port = shift;

        use Dancer;
        use Dancer::Plugin::Ajax;

        setting access_log => 0;
        setting port => $port;

        ajax '/req' => sub {
            return 1;
        };
        get '/foo' => sub {
            return 'not ajax';
        };
        ajax '/foo' => sub {
            return 'ajax';
        };
        get '/bar' => sub {
            return 'not ajax';
        };
        get '/bar', {ajax => 1} => sub {
            return 'ajax';
        };
        start();
    },
);
