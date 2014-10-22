package SockJS::Transport::JSONPSend;

use strict;
use warnings;

use base 'SockJS::Transport::Base';

sub new {
    my $self = shift->SUPER::new(@_);

    push @{$self->{allowed_methods}}, 'POST';

    return $self;
}

sub dispatch_POST {
    my $self = shift;
    my ($env, $session, $path) = @_;

    return [404, [], ['Not found']] unless $session->is_connected;

    my $data = $self->_get_content($env);
    return $self->_return_send_error('Payload expected.') unless length $data;

    my $message;
    eval { $message = JSON::decode_json($data) } || do {
        return $self->_return_send_error('Broken JSON encoding.');
    };

    if (@$message) {
        $session->event('data', @$message);
    }

    return [
        200,
        [   'Content-Type'                     => 'text/plain; charset=UTF-8',
            'Content-Length'                   => 2,
            'Access-Control-Allow-Origin'      => '*',
            'Access-Control-Allow-Credentials' => 'true'
        ],
        ['ok']
    ];
}

sub _get_content {
    my $self = shift;
    my ($env) = @_;

    my $content_length = $env->{CONTENT_LENGTH} || 0;
    my $rcount = $env->{'psgi.input'}->read(my $chunk, $content_length);

    SockJS::Exception->throw(500) unless $rcount == $content_length;

    my $d;

    if ($env->{CONTENT_TYPE} eq 'application/x-www-form-urlencoded') {
        $chunk =~ s{\+}{ }g;
        ($d) = $chunk =~ m/(?:^|&|;)d=([^&;]*)/;
        $d =~ s/%(..)/chr(hex($1))/eg if defined $d;
    }
    else {
        $d = $chunk;
    }

    return $d;
}

sub _return_send_error {
    my $self = shift;
    my ($error) = @_;

    return [500, ['Content-Type' => 'text/plain; charset=UTF-8'], [$error]];
}

1;
