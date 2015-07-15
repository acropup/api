package VHSAPI;
use Dancer ':syntax';
use Dancer::Plugin::XML::RSS;
use VHSAPI::Hackspace;
use HTML::Entities;

our $VERSION = '0.10000001';

hook before => sub {
    if (request->path =~ m#^/s/(\w+)#) {
        var space => VHSAPI::Hackspace->By_name($1);
    }
};

hook before_template => sub {
    my $p = shift;
    $p->{hackspaces} = VHSAPI::Hackspace->All;
    $p->{space} = vars->{space};
};

get '/' => sub {
    template 'index';
};

get '/s/:spacename/data/history/:dataname.json' => sub {
    my $space = vars->{space} or redirect '/';
    my $dp = $space->datapoint(params->{dataname});
    my $offset = params->{offset} || 0;
    return { error => "Bad offset" } unless $offset =~ m/^\d+$/;
    my $limit = params->{limit}   || 100;
    return { error => "Bad limit" } unless $limit =~ m/^\d+$/;
    $limit = 100 if $limit > 100;
    my $h = $dp->history($offset, $limit);
    return {
        offset => $offset,
        limit  => $limit,
        count  => scalar(@$h),
        data   => $h,
    };
};

get '/s/:spacename/data/:dataname.json' => sub {
    my $space = vars->{space} or redirect '/';
    my $dp = $space->datapoint(params->{dataname});
    return $dp->to_hash;
};

get '/s/:spacename/data/:dataname.txt' => sub {
    my $space = vars->{space} or redirect '/';
    my $dp = $space->datapoint(params->{dataname});
    content_type 'text/plain';
    return $dp->value;
};

get '/s/:spacename/data/:dataname/feed' => sub {
    my $space = vars->{space} or redirect '/';
    my $dp = $space->datapoint(params->{dataname});
    rss->channel(
        title => $space->title . " - " . $dp->name,
        link => 'http://api.hackspace.ca',
        description => "Datapoint information",
    );
    my $w3c = DateTime::Format::W3CDTF->new;
    rss->add_item(
        title => $dp->name . " is " . $dp->value,
        link => $dp->url,
        description => $space->title . " datapoint '@{[$dp->name]}' is now '@{[$dp->value]}' as of @{[$dp->datetime]}.",
        dc => {
            date => $w3c->format_datetime($dp->datetime),
        },
    );
    rss_output;
};

get '/s/:spacename/data/:dataname/update' => sub {
    my $space = vars->{space} or redirect '/';
    my $dataname = params->{dataname};
    my $value    = params->{value};

    # Sanitize data names and values
    my $sanitize_rx_n = qr/[^A-Za-z0-9_\-]/;
    my $sanitize_rx_v = qr/[^A-Za-z0-9_\-\.: ]/;
    $dataname =~ s/$sanitize_rx_n//g;
    $value    =~ s/$sanitize_rx_v//g;

    my $dp    = $space->datapoint($dataname);
    if ($dp) {
        debug "Updating datapoint";
        $dp->update($value);
    }
    else {
        debug "Creating datapoint";
        $dp = $space->add_datapoint($dataname, $value);
    }
    return { status => 'OK', result => $dp->to_hash };
};

get '/s/:spacename/data/:dataname.js' => sub {
    my $space = vars->{space} or redirect '/';
    content_type 'application/javascript';
    template 'data-widget', {
        space => $space,
        datapoint => $space->datapoint(params->{dataname})
     }, {layout => undef };
};

get '/s/:spacename/data/:dataname1/:dataname2/fullpage' => sub {
    my $space = vars->{space} or redirect '/';
    template 'data-dual-full', {
        datapoint1 => encode_entities($space->datapoint(params->{dataname1})),
        datapoint2 => encode_entities($space->datapoint(params->{dataname2}))
        }, {layout => undef};
};

get '/s/:spacename/data/:dataname/fullpage' => sub {
    my $space = vars->{space} or redirect '/';
    template 'data-full', { datapoint => encode_entities($space->datapoint(params->{dataname})) },
                          {layout => undef};
};

get '/s/:spacename/data/:dataname' => sub {
    my $space = vars->{space} or redirect '/';
    template 'data', { datapoint => encode_entities($space->datapoint(params->{dataname})) };
};


true;
