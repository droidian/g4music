namespace Music {
    public const string UNKOWN_ALBUM = _("Unknown Album");
    public const string UNKOWN_ARTIST = _("Unknown Aritst");
    public const string DEFAULT_MIMETYPE = "audio/mpeg";

    public class Song : Object {
        public bool has_tags = false;

        public string album = "";
        public string artist = "";
        public string title = "";
        public string uri = "";
        public int track = int.MAX;

        //  for sorting
        private string _album_key = "";
        private string _artist_key = "";
        private string _title_key = "";
        private int _album_num = int.MAX;
        private int _artist_num = int.MAX;
        private int _title_num = int.MAX;
        private int _order = 0;

        private string? _cover_uri = null;

        public string cover_uri {
            get {
                return _cover_uri ?? uri;
            }
            set {
                _cover_uri = value;
            }
        }

        public void from_gst_tags (Gst.TagList? tags) {
            string? al = null, ar = null, ti = null;
            uint tr = 0;
            if (tags != null) {
                tags?.get_string (Gst.Tags.ALBUM, out al);
                tags?.get_string (Gst.Tags.ARTIST, out ar);
                tags?.get_string (Gst.Tags.TITLE, out ti);
                tags?.get_uint (Gst.Tags.TRACK_NUMBER, out tr);
            }
            this.album = (al != null && al?.length > 0) ? (!)al : UNKOWN_ALBUM;
            this.artist = (ar != null && ar?.length > 0) ? (!)ar : UNKOWN_ARTIST;
            if (ti != null && ti?.length > 0) this.title = (!)ti;
            if ((int) tr > 0) this.track = (int) tr;
            has_tags = true;
            update_keys ();
        }

#if HAS_TAGLIB_C
        public void from_taglib (TagLib.File file) {
            string? al = null, ar = null, ti = null;
            uint tr = 0;
            if (file.is_valid ()) {
                unowned var tags = file.tag;
                al = tags.album;
                ar = tags.artist;
                ti = tags.title;
                tr = tags.track;
            }
            this.album = (al != null && al?.length > 0) ? (!)al : UNKOWN_ALBUM;
            this.artist = (ar != null && ar?.length > 0) ? (!)ar : UNKOWN_ARTIST;
            if (ti != null && ti?.length > 0) this.title = (!)ti;
            if ((int) tr > 0) this.track = (int) tr;
            has_tags = true;
            update_keys ();
        }
#endif

        public void update_keys () {
            _album_key = album.collate_key ();
            _artist_key = artist.collate_key ();
            _title_key = title.collate_key ();
            _album_num = get_prefix_number (album);
            _artist_num = get_prefix_number (artist);
            _title_num = get_prefix_number (title);
        }

        public static int compare_by_album (Object obj1, Object obj2) {
            var s1 = (Song) obj1;
            var s2 = (Song) obj2;
            int ret = s1._album_num - s2._album_num;
            if (ret != 0) return ret;
            ret = strcmp (s1._album_key, s2._album_key);
            if (ret != 0) return ret;
            ret = s1.track - s2.track;
            if (ret != 0) return ret;
            ret = s1._title_num - s2._title_num;
            if (ret != 0) return ret;
            ret = strcmp (s1._title_key, s2._title_key);
            if (ret != 0) return ret;
            return strcmp (s1.uri, s2.uri);
        }

        public static int compare_by_artist (Object obj1, Object obj2) {
            var s1 = (Song) obj1;
            var s2 = (Song) obj2;
            int ret = s1._artist_num - s2._artist_num;
            if (ret != 0) return ret;
            ret = strcmp (s1._artist_key, s2._artist_key);
            if (ret != 0) return ret;
            ret = s1._title_num - s2._title_num;
            if (ret != 0) return ret;
            ret = strcmp (s1._title_key, s2._title_key);
            if (ret != 0) return ret;
            return strcmp (s1.uri, s2.uri);
        }

        public static int compare_by_title (Object obj1, Object obj2) {
            var s1 = (Song) obj1;
            var s2 = (Song) obj2;
            int ret = s1._title_num - s2._title_num;
            if (ret != 0) return ret;
            ret = strcmp (s1._title_key, s2._title_key);
            if (ret != 0) return ret;
            ret = s1._artist_num - s2._artist_num;
            if (ret != 0) return ret;
            ret = strcmp (s1._artist_key, s2._artist_key);
            if (ret != 0) return ret;
            return strcmp (s1.uri, s2.uri);
        }

        public static int compare_by_order (Object obj1, Object obj2) {
            var s1 = (Song) obj1;
            var s2 = (Song) obj2;
            return s1._order - s2._order;
        }

        public static void shuffle_order (GenericArray<Object> arr) {
            for (var i = arr.length - 1; i > 0; i--) {
                var r = Random.int_range (0, i);
                var s = arr[i];
                arr[i] = arr[r];
                arr[r] = s;
                ((Song)arr[i])._order = i;
            }
        }
    }

    public static int find_first_letter (string text) {
        var index = 0;
        var next = 0;
        var c = text.get_char (0);
        do {
            if ((c >= '0' && c <= '9')
                    || (c >= 'a' && c <= 'z')
                    || (c >= 'A' && c <= 'Z')
                    || c >= 0xff) {
                return index;
            }
            index = next;
        }  while (text.get_next_char (ref next, out c));
        return -1;
    }

    public static int get_prefix_number (string text) {
        if (text.length == 0) {
            return int.MAX;
        }

        int num = 0;
        var next = 0;
        var c = text.get_char (0);
        do {
            if (c >= '0' && c <= '9') {
                num = num * 10 + (int) (c - '0');
            } else {
                break;
            }
        }  while (text.get_next_char (ref next, out c));
        return num != 0 ? num : int.MAX;
    }

    public static string get_uri_with_end_sep (File file) {
        var uri = file.get_uri ();
        if (uri[uri.length - 1] != '/')
            uri += "/";
        return uri;
    }

    public static string parse_abbreviation (string text) {
        var sb = new StringBuilder ();
        foreach (var s in text.split (" ")) {
            var index = find_first_letter (s);
            if (index >= 0) {
                sb.append (s.get_char (index).to_string ());
                if (sb.str.char_count () >= 2)
                    break;
            }
        }

        if (sb.str.char_count () >= 2) {
            return sb.str.up ();
        } else if (text.char_count () > 2) {
            var index = text.index_of_nth_char (2);
            return text.substring (0, index).up ();
        }
        return text.up ();
    }
}