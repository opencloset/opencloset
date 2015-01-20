package OpenCloset::Parcel::KR::CJ;

sub new { bless {}, shift }

sub tracking_url {
    my ( $self, $number ) = @_;
    return
        sprintf
        "https://www.doortodoor.co.kr/main/doortodoor.do?fsp_action=PARC_ACT_002&fsp_cmd=retrieveInvNoACT&invc_no=%s&nextpage=parcel/ajax/retrieveInvNo.jsp",
        $number;
}

sub url { shift->tracking_url(@_) }

1;
