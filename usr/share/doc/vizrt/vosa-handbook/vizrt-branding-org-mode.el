;; load all locally installed packages
(let ((default-directory "/usr/local/src/emacs"))
  (normal-top-level-add-subdirs-to-load-path))

(require 'org-export)

;; don't create a footer
(setq org-export-html-postamble nil)

;; These two settings make exported HTML look like our Vizrt branded
; release notes.
(setq org-export-html-preamble "<script>
function renderclockiframe(url) {
  var val='';
  val += '<iframe src=\"http://';
  val += url;
  val += '\" frameborder=\"0\" width=\"126\" height=\"42\" allowTransparency=\"true\" style=\"float:right\">'
  val += '</iframe>';
  return val;
}
</script><svg
        id=\"vizrt-logo\"
        version=\"1.1\"
        width=\"138\"
        height=\"84\"
        > 
  <g
          id=\"g12\"
          transform=\"matrix(1.25,0,0,-1.25,-451.34003,425.24315)\"> 
    <g
            id=\"g14\"
            transform=\"matrix(0.0246257,0,0,0.02458666,313.76213,231.21317)\"> 
      <path
              d=\"m 3060.56,3437.2 -209.9,-593.4 -207.05,593.4 -215.82,0 326.08,-866.38 184.92,0 332.24,866.38 -210.47,0\"
              style=\"fill:#f57615;fill-opacity:1;fill-rule:evenodd;stroke:none\"
              id=\"path16\"/> 
      <path
              d=\"m 3473.3,2569.82 193.547,0 0,866.531 -193.547,0 0,-866.531 z\"
              style=\"fill:#f57615;fill-opacity:1;fill-rule:evenodd;stroke:none\"
              id=\"path18\"/> 
      <path
              d=\"m 3916.16,3436.36 -0.14,-177.24 364.23,0 -372.91,-554.74 0,-133.56 616.08,0 0,175.25 -374.66,0 366.68,550.78 0,139.51 -599.28,0\"
              style=\"fill:#f57615;fill-opacity:1;fill-rule:evenodd;stroke:none\"
              id=\"path20\"/> 
      <path
              d=\"m 4961.8,3436.66 c -56.15,0 -99.9,-9.02 -144.01,-53.04 -42.13,-42.13 -63.55,-93.63 -63.55,-153.7 l 0,-658.85 193.26,0 0,629.18 c 0,16.39 5.76,30.04 17.53,41.82 9.79,9.87 32.16,17.44 52.18,17.44 l 161.49,0 0,177.15 -216.9,0\"
              style=\"fill:#f57615;fill-opacity:1;fill-rule:evenodd;stroke:none\"
              id=\"path22\"/> 
      <path
              d=\"m 5367.91,3699.54 0,-915.91 c 0,-58.68 20.75,-109.43 62.13,-150.8 43.31,-43.47 85.57,-62.01 141.03,-62.01 l 212.69,0 0,174.7 -158.78,0 c -15.96,0 -28.96,5.5 -40.72,16.87 -11.19,11.53 -16.76,24.5 -16.76,40.65 l 0,456.42 216.26,0 0,176.39 -216.26,0 0,263.69 -199.59,0\"
              style=\"fill:#f57615;fill-opacity:1;fill-rule:evenodd;stroke:none\"
              id=\"path24\"/> 
      <path
              d=\"m 1921.16,3066.86 c -0.39,-514.15 173.24,-988.49 465.56,-1367.51 l 69.26,204.63 c -205.49,300.61 -333.44,658.06 -355.3,1043.68 l -179.52,119.2\"
              style=\"fill:#f57615;fill-opacity:1;fill-rule:evenodd;stroke:none\"
              id=\"path26\"/> 
      <path
              d=\"m 6404.28,3065.28 c 0.49,513.97 -173.17,988.55 -465.37,1367.26 l -69.46,-204.34 c 205.52,-300.7 333.61,-658.34 355.24,-1043.68 l 179.59,-119.24\"
              style=\"fill:#f57615;fill-opacity:1;fill-rule:evenodd;stroke:none\"
              id=\"path28\"/> 
 
    </g> 
  </g> 
</svg><div><!-- opening a div to counter the close of #preamble-->
"

      org-export-html-postamble t
      org-export-html-postamble-format (quote (("en" "<hr/>
<p class=\"author\">
  Author: %a (%e)
  Date: %d
</p>
<!-- close #postamble --></div>
<!-- find all links containing tcl.nie.cust.vizrtsaas and add the special class.-->
<script type='text/javascript'>
  var intLinks = document.links;
  for(var i = 0; i < intLinks.length; i++){
    if(intLinks[i].href.indexOf('cust.vizrtsaas') > -1) {
      intLinks[i].className += 'special';
    }
  }
</script><!--preamble is closed by emacs-->")))
      org-export-html-style "<style type=\"text/css\">
.title  { text-align: left; }

body {
  font-family: Lucida Sans Unicode, sans-serif;
  font-size: 0.80em;
  line-height: 1.3em;
  background-color: #D1D4D3;
  margin: 15px 0;
}


#text-table-of-contents ul {
  margin: 0;
  padding: 0;
  list-style: none;
}

#table-of-contents {
  margin-top: 50px;
}

#table-of-contents a {
  color: #666666;
  text-decoration: none;
}

#table-of-contents ul {
  margin: 0;
  padding: 0;
  list-style: none;
}

#table-of-contents li {
  margin: 15px 0 0 0;
  font-weight: bold;

}

#table-of-contents li ul {
  margin: 10px 0 0 0;
}

#table-of-contents li ul li {
  margin: 0 0 0 30px;
  padding: 0;
}


#preamble {
  padding: 60px;
  margin: 0 auto;
  max-width: 760px;
  border: 1px solid #818A71;
  background-color: white;
}

h1, h2 {
  color: #E98300;
  font-family: Georgia, serif;
}

h1 {
  font-size: 1.8em;
  margin: 40px 0 20px 0;
}

h2 {
  font-size: 1.4em;
  margin: 30px 0 10px 0;
}

h3, h4, h5, h6 {
  font-weight: bold;
  margin: 20px 0 5px 0;
}

h3, h4, h5 {
}

h6 {
}

a {
  color: #3366cc;
  text-decoration: none;
}

a.special {
  display: inline-block;
  color: #36C;
  background-color: #EEE;
  text-decoration: none;
  border-radius: 5px;
  border: 1px solid #CFD8F6;
  padding: 1px 5px;
  margin-bottom: 1px;
}


a:hover {
  text-decoration: underline;
}

dl {
  margin: 0;
  padding: 0;
}
dt {
  font-weight: bold;
  margin: 15px 0 10px 0;
  padding: 0;
}

dd {
  margin: 0 0 0 30px;
  padding: 0;
}


p {
  margin-top: 0.2em;
  margin-bottom: 0.6em;
}

pre.programlisting {
  font-family: courier, monospace;
  margin-top: 0;
  background-color: #ffddaa;
  padding-top: 0.5em;
  padding-bottom: 0.5em;
  padding-left: 0.5em;
  padding-right: 0.5em;
  display: block;
  overflow: auto;
}

.literal {
  font-family: courier, monospace;
}

em {
  font-weight: bold;
  font-style: normal;
}

em.replaceable {
  font-weight: normal;
  font-style: italic;
}

div.note {
  background-color: #ffddaa;
  padding-top: 0.5em;
  padding-bottom: 0.5em;
  padding-left: 0.5em;
  padding-right: 0.5em;
  display: block;
  overflow: auto;
}

#postamble {
  margin-top: 50px;
}

@media screen and (max-width : 600px) {
  #preamble {
    padding: 5px;
  }
}


</style>
"
      )
