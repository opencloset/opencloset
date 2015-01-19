package OpenCloset::Parcel::KR::Yellowcap;

sub new { bless {}, shift }

sub tracking_url {
    my ( $self, $number ) = @_;
    return
        sprintf
        "https://www.kgyellowcap.co.kr/delivery/waybill.html?mode=bill&delivery=%s",
        $number;
}

sub url { shift->tracking_url(@_) }

1;
