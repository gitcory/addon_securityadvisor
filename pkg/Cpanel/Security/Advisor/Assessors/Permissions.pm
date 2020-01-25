package Cpanel::Security::Advisor::Assessors::Permissions;

# Copyright (c) 2016, cPanel, Inc.
# All rights reserved.
# http://cpanel.net
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#     * Neither the name of the owner nor the names of its contributors may
#       be used to endorse or promote products derived from this software
#       without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL cPanel, L.L.C. BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

use strict;

use base 'Cpanel::Security::Advisor::Assessors';

sub generate_advice {
    my ($self) = @_;
    $self->_check_for_unsafe_permissions();

    return 1;
}

sub _check_for_unsafe_permissions {
    my ($self) = @_;

    my %test_files = (
        '/etc/shadow' => { 'perms' => [ 0200, 0600 ], 'uid' => 0, 'gid' => 0 },
        '/etc/passwd' => { 'perms' => [0644], 'uid' => 0, 'gid' => 0 }
    );

    for my $file ( keys %test_files ) {
        my $expected_attributes = $test_files{$file};
        my ( $current_mode, $uid, $gid ) = ( stat($file) )[ 2, 4, 5 ];
        my $perms_ok = 0;
        foreach my $allowed_perms ( @{ $expected_attributes->{'perms'} } ) {
            if ( ( $allowed_perms & 07777 ) == ( $current_mode & 07777 ) ) {
                $perms_ok = 1;
                last;
            }
        }
        if ( !$perms_ok ) {
            my $expected_mode = join( ' ', map { sprintf( '%04o', $_ ) } @{ $expected_attributes->{'perms'} } );
            my $actual_mode = sprintf( "%04o", $current_mode & 07777 );
            $self->add_warn_advice(
                'key'  => q{Permissions_are_non_default},
                'text' => $self->_lh->maketext( "[_1] has non default permissions.  Expected: [_2], Actual: [_3].", $file, $expected_mode, $actual_mode ),
                'suggestion' => $self->_lh->maketext( "Review the permissions on [_1] to ensure they are safe", $file ),
            );
        }

        if ( $uid != $expected_attributes->{'uid'} or $gid != $expected_attributes->{'gid'} ) {
            $self->add_warn_advice(
                'key'        => q{Permissions_has_non_root_users},
                'text'       => $self->_lh->maketext( "[_1] has non root user and/or group", $file ),
                'suggestion' => $self->_lh->maketext( "Review the ownership permissions on [_1]", $file ),
            );
        }
    }

    return 1;
}

1;
