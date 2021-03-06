package Zadm::Image::Joyent;
use Mojo::Base 'Zadm::Image::base';

use Mojo::JSON qw(decode_json);
use Mojo::File;

has baseurl  => 'https://images.joyent.com/images';
has index    => sub { shift->baseurl };

sub postProcess {
    my $self = shift;
    my $json = decode_json(shift) // [];

    return [
        map { {
            uuid   => $_->{uuid},
            name   => $_->{name},
            desc   => $_->{description},
            vers   => $_->{version},
            img    => $self->baseurl . "/$_->{uuid}/file",
            brand  => $_->{requirements}->{brand} // 'illumos',
            type   => $_->{type},
            comp   => $_->{files}->[0]->{compression},
            ext    => $_->{type} eq 'lx-dataset' ? '.tar.gz' : '.gz',
            kernel => $_->{tags}->{'kernel-version'},
            chksum => {
                digest => 'sha1',
                chksum => $_->{files}->[0]->{sha1},
            },
        } }
        grep { $_->{requirements}->{brand} || $_->{type} eq 'zone-dataset' }
        @$json
    ];
}

sub postInstall {
    my $self  = shift;
    my $brand = shift;
    my $opts  = shift // {};

    return if $brand ne 'illumos';

    # illumos branded images from Joyent have a different structure to that
    # which we expect. The zone root ends up containing a number of directories
    # including one called root/ which is the real zone root. We need to move
    # this into place while keeping within the same filesystem to avoid
    # unecessary copying.

    my $root = Mojo::File->new($opts->{zonepath}, 'root');
    my $newroot = $root->child('root');
    return if !-d $newroot->path;

    $root->list({ dir => 1 })
        ->grep(sub { $_->path ne $newroot->path })
        ->map(sub { $_->remove_tree });
    $newroot->move_to($newroot->sibling('__root'));
    $newroot = $newroot->sibling('__root');
    $newroot->list({ dir => 1 })->map(sub {
        my $base = $root->child($_->basename);
        $self->log->debug("Moving $_ to $base");
        $_->move_to($base);
    });
    $newroot->remove_tree;
    $root->chmod(0755);
}

1;

__END__

=head1 COPYRIGHT

Copyright 2020 OmniOS Community Edition (OmniOSce) Association.

=head1 LICENSE

This program is free software: you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the Free
Software Foundation, either version 3 of the License, or (at your option)
any later version.
This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
more details.
You should have received a copy of the GNU General Public License along with
this program. If not, see L<http://www.gnu.org/licenses/>.

=head1 AUTHOR

S<Dominik Hassler E<lt>hadfl@omniosce.orgE<gt>>

=head1 HISTORY

2020-04-12 had Initial Version

=cut
