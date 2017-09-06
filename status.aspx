<%@ Import Namespace="System" %>
<%@ Import Namespace="System.IO" %>
<%@ Import Namespace="System.Web" %>
<%@ Import Namespace="System.Xml" %>
<%@ Import Namespace="System.Reflection" %>
<%@ Import Namespace="System.Diagnostics" %>
<%@ Page Language="c#" debug="true" %>
<script runat="server">

private XmlDocument customSettings = null;

private string getWebBaseUrl()
{
  GetCustomSettings();
  return customSettings.SelectSingleNode("//appSettings/add[@key='PublicWebBaseUrl']").Attributes["value"].Value.ToLowerInvariant();
}

private string getHost()
{
  var uri = new Uri(getWebBaseUrl());
  return uri.Host;
}

private void GetCustomSettings()
{
  if (this.customSettings == null)
  {
    var dir = Directory.EnumerateDirectories(@"C:\Program Files\Microsoft Dynamics NAV").Last();
    customSettings = new XmlDocument();
    customSettings.Load(dir + @"\Service\CustomSettings.config");
  }
}

private string getLandingPageUrl()
{
  return getHost();
}
</script>
<html>
<head>
    <title>Microsoft Dynamics NAV Installation Status</title>
    <style type="text/css">
        body {
            font-family: "Segoe UI","Lucida Grande",Verdana,Arial,Helvetica,sans-serif;
            font-size: 16px;
            color: #c0c0c0;
            background: #000000;
            margin-left: 20px;
        }

    </style>
<script type="text/JavaScript">
function timeRefresh(timeoutPeriod) 
{
  setTimeout("refresh();",timeoutPeriod);
}

function refresh() 
{
  if (window.location.href.indexOf('?norefresh') == -1)
  {
    location.reload(true);
  }
}
</script>
</head>
<body onload="JavaScript:timeRefresh(10000);">
<p>
<a href="http://<%=getLandingPageUrl() %>">View Landing Page</a>&nbsp;&nbsp;
<%
if (Request.Url.AbsoluteUri.Contains("norefresh")) {
%>
  <a href="http://<%=getLandingPageUrl() %>/status.aspx">Enable refresh</a>&nbsp;&nbsp;
<%
} else {
%>
  <a href="http://<%=getLandingPageUrl() %>/status.aspx?norefresh">Disable refresh</a>
<%
}
%>
</p><hr>
<%
  try
  {
    var lines = System.IO.File.ReadAllLines(@"c:\demo\status.txt");
    Array.Reverse(lines);
    foreach(var line in lines) {
%>
<%=line %><br>
<%
    }
  } catch(Exception) 
  {
%>
  <p>Error loading status, page should refresh in 10 seconds.</p>
<%
  }
%>
</body>
</html>
