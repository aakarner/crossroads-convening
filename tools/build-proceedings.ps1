# Converts the proceedings Word file into the content regions of proceedings.html.
# Usage: powershell -ExecutionPolicy Bypass -File tools\build-proceedings.ps1 -Docx "path\to\Crossroads Convening Summary.docx"
#
# Only the text between the BEGIN/END marker comments in proceedings.html is replaced,
# so the page design can be edited freely around them.
param([Parameter(Mandatory = $true)][string]$Docx)

$ErrorActionPreference = "Stop"
$W = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
$R = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$page = Join-Path $root "proceedings.html"
$utf8 = New-Object Text.UTF8Encoding $false

# ---------- Read the parts we need from the .docx (a zip file) ----------

Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead((Resolve-Path $Docx).Path)
function Read-Part([string]$name) {
  $entry = $zip.GetEntry($name)
  if (-not $entry) { return $null }
  $reader = New-Object IO.StreamReader($entry.Open(), [Text.Encoding]::UTF8)
  $xml = New-Object Xml.XmlDocument
  $xml.LoadXml($reader.ReadToEnd())
  $reader.Close()
  return $xml
}
$doc = Read-Part "word/document.xml"
$numbering = Read-Part "word/numbering.xml"
$docRels = Read-Part "word/_rels/document.xml.rels"
$fnDoc = Read-Part "word/footnotes.xml"
$fnRels = Read-Part "word/_rels/footnotes.xml.rels"
$zip.Dispose()

function Get-Links($rels) {
  $map = @{}
  if ($rels) { foreach ($rel in $rels.DocumentElement.ChildNodes) { $map[$rel.GetAttribute("Id")] = $rel.GetAttribute("Target") } }
  return $map
}
$docLinks = Get-Links $docRels
$fnLinks = Get-Links $fnRels

function Child($node, [string]$name) { foreach ($c in $node.ChildNodes) { if ($c.LocalName -eq $name) { return $c } }; return $null }
function Val($node) { if ($node) { $node.GetAttribute("val", $W) } }
function On($node) { $node -and ((Val $node) -notin @("0", "false")) }
function Esc([string]$s) { $s.Replace("&", "&amp;").Replace("<", "&lt;").Replace(">", "&gt;").Replace('"', "&quot;") }

# Bullet vs. numbered list, from numbering.xml
function Get-ListTag([string]$numId, [string]$ilvl) {
  $nsm = New-Object Xml.XmlNamespaceManager $numbering.NameTable
  $nsm.AddNamespace("w", $W)
  $abs = Val $numbering.SelectSingleNode("//w:num[@w:numId='$numId']/w:abstractNumId", $nsm)
  $fmt = Val $numbering.SelectSingleNode("//w:abstractNum[@w:abstractNumId='$abs']/w:lvl[@w:ilvl='$ilvl']/w:numFmt", $nsm)
  if ($fmt -eq "bullet") { "ul" } else { "ol" }
}

# ---------- Inline text: runs, bold/italic, links, footnote references ----------

$footnoteOrder = New-Object Collections.ArrayList

function Get-Segments($node, $links, $href) {
  foreach ($c in $node.ChildNodes) {
    switch ($c.LocalName) {
      "r" {
        $rPr = Child $c "rPr"
        $bold = [bool]($rPr -and (On (Child $rPr "b")))
        $italic = [bool]($rPr -and (On (Child $rPr "i")))
        foreach ($rc in $c.ChildNodes) {
          $text = $null; $fn = $null
          switch ($rc.LocalName) {
            "t" { $text = $rc.InnerText }
            "tab" { $text = " " }
            "br" { $text = "`n" }
            "footnoteReference" { $fn = $rc.GetAttribute("id", $W) }
          }
          if ($null -ne $text -or $fn) {
            [pscustomobject]@{ Text = $text; Bold = $bold; Italic = $italic; Href = $href; Fn = $fn }
          }
        }
      }
      "hyperlink" {
        $id = $c.GetAttribute("id", $R)
        $target = if ($id -and $links.ContainsKey($id)) { $links[$id] } else { $null }
        Get-Segments $c $links $target
      }
      { $_ -in @("ins", "smartTag", "fldSimple", "sdt", "sdtContent", "customXml") } { Get-Segments $c $links $href }
    }
  }
}

function Convert-Inline($node, $links) {
  $sb = New-Object Text.StringBuilder
  $open = $null
  foreach ($s in @(Get-Segments $node $links $null)) {
    if ($s.Href -ne $open) {
      if ($open) { [void]$sb.Append("</a>") }
      if ($s.Href) { [void]$sb.Append("<a href=""$(Esc $s.Href)"">") }
      $open = $s.Href
    }
    if ($s.Fn) {
      if ($footnoteOrder -notcontains $s.Fn) { [void]$footnoteOrder.Add($s.Fn) }
      $n = $footnoteOrder.IndexOf($s.Fn) + 1
      [void]$sb.Append("<sup class=""fnref""><a href=""#fn$n"" id=""fnref$n"" aria-label=""Note $n"">$n</a></sup>")
      continue
    }
    $t = (Esc $s.Text).Replace("`n", "<br>")
    # keep spaces outside the formatting tags ("<strong>Title.</strong> Text", not "<strong>Title. </strong>Text")
    $m = [regex]::Match($t, "^(\s*)(.*?)(\s*)$", "Singleline")
    $inner = $m.Groups[2].Value
    if ($inner) {
      if ($s.Italic) { $inner = "<em>$inner</em>" }
      if ($s.Bold) { $inner = "<strong>$inner</strong>" }
    }
    [void]$sb.Append($m.Groups[1].Value + $inner + $m.Groups[3].Value)
  }
  if ($open) { [void]$sb.Append("</a>") }
  $html = $sb.ToString()
  do {
    $before = $html
    $html = $html -replace "</strong>(\s*)<strong>", '$1' -replace "</em>(\s*)<em>", '$1'
  } while ($html -ne $before)
  return ($html -replace "\s{2,}", " ").Trim()
}

function Get-PlainText($p) { (($p.GetElementsByTagName("t", $W) | ForEach-Object { $_.InnerText }) -join "").Trim() }

# ---------- Walk the document body ----------

$usedIds = @{}
function New-Id([string]$text) {
  $id = ($text.ToLower() -replace "&", "and" -replace "[^a-z0-9]+", "-").Trim("-")
  if ($id.Length -gt 60) { $id = $id.Substring(0, 60).Trim("-") }
  $base = $id; $i = 2
  while ($usedIds.ContainsKey($id)) { $id = "$base-$i"; $i++ }
  $usedIds[$id] = $true
  return $id
}

$body = New-Object Collections.ArrayList
$credits = New-Object Collections.ArrayList
$toc = New-Object Collections.ArrayList
$list = $null          # current list: @{ Tag; Items }
$inChapter = $false
$inToc2 = $false
$frontMatter = $true
$creditGroup = $null   # current front-matter group: @{ Title; Items; Paras }
$creditGroups = New-Object Collections.ArrayList
$seenTitle = $false

function Close-List {
  if ($script:list) {
    [void]$body.Add("<$($list.Tag)>")
    foreach ($li in $list.Items) { [void]$body.Add("  <li>$li</li>") }
    [void]$body.Add("</$($list.Tag)>")
    $script:list = $null
  }
}

foreach ($node in (Child $doc.DocumentElement "body").ChildNodes) {
  if ($node.LocalName -ne "p") { continue }   # skips the Word table of contents (sdt) and section settings
  $pPr = Child $node "pPr"
  $style = if ($pPr) { Val (Child $pPr "pStyle") } else { $null }
  if (-not $style) { $style = "Normal" }   # switch skips $null entirely, so give unstyled paragraphs a name
  $numPr = if ($pPr) { Child $pPr "numPr" } else { $null }
  $plain = Get-PlainText $node

  if ($style -eq "Heading1") { $frontMatter = $false }

  # Front matter (title, committee, notetakers, acknowledgments) becomes the credits block
  if ($frontMatter) {
    if (-not $plain) { $creditGroup = $null; continue }
    if (-not $seenTitle) { $seenTitle = $true; continue }                       # report title
    if ($plain -match "^[A-Z][a-z]+ \d{1,2}, \d{4}$") { continue }              # report date
    if ($plain -eq "Table of Contents") { continue }
    $runs = @($node.GetElementsByTagName("r", $W) | Where-Object { (Get-PlainText $_) })
    $allBold = $runs.Count -gt 0 -and -not ($runs | Where-Object { -not ((Child $_ "rPr") -and (On (Child (Child $_ "rPr") "b"))) })
    if ($plain.EndsWith(":") -or $allBold) {
      $creditGroup = @{ Title = $plain.TrimEnd(":"); Items = New-Object Collections.ArrayList; Paras = New-Object Collections.ArrayList }
      [void]$creditGroups.Add($creditGroup)
    } elseif ($creditGroup) {
      if ($plain.Length -gt 120) { [void]$creditGroup.Paras.Add((Convert-Inline $node $docLinks)) }
      else { [void]$creditGroup.Items.Add((Convert-Inline $node $docLinks)) }
    }
    continue
  }

  if ($numPr) {
    $tag = Get-ListTag (Val (Child $numPr "numId")) (Val (Child $numPr "ilvl"))
    if ($list -and $list.Tag -ne $tag) { Close-List }
    if (-not $list) { $list = @{ Tag = $tag; Items = New-Object Collections.ArrayList } }
    [void]$list.Items.Add((Convert-Inline $node $docLinks))
    continue
  }
  Close-List
  if (-not $plain) { continue }

  switch ($style) {
    "Heading1" {
      if ($inToc2) { [void]$toc.Add("    </ol>"); $inToc2 = $false }
      if ($toc.Count) { [void]$toc.Add("  </li>") }
      if ($inChapter) { [void]$body.Add("</section>") }
      $id = New-Id $plain
      [void]$body.Add("<section class=""chapter"" aria-labelledby=""$id"">")
      [void]$body.Add("<h2 id=""$id"">$(Esc $plain)</h2>")
      [void]$toc.Add("  <li class=""toc__stop toc__stop--major""><a href=""#$id"">$(Esc $plain)</a>")
      $inChapter = $true
    }
    "Heading2" {
      $id = New-Id $plain
      [void]$body.Add("<h3 id=""$id"">$(Esc $plain)</h3>")
      if (-not $inToc2) { [void]$toc.Add("    <ol>"); $inToc2 = $true }
      [void]$toc.Add("      <li class=""toc__stop""><a href=""#$id"">$(Esc $plain)</a></li>")
    }
    "Heading3" { [void]$body.Add("<h4>$(Esc $plain)</h4>") }
    default { [void]$body.Add("<p>$(Convert-Inline $node $docLinks)</p>") }
  }
}
Close-List
if ($inChapter) { [void]$body.Add("</section>") }
if ($inToc2) { [void]$toc.Add("    </ol>") }
if ($toc.Count) { [void]$toc.Add("  </li>") }

# ---------- Footnotes ----------

if ($footnoteOrder.Count -and $fnDoc) {
  [void]$body.Add("<section class=""footnotes"" aria-labelledby=""notes"">")
  [void]$body.Add("<h2 id=""notes"">Notes</h2>")
  [void]$body.Add("<ol>")
  $n = 0
  foreach ($fid in $footnoteOrder) {
    $n++
    $fn = $fnDoc.DocumentElement.ChildNodes | Where-Object { $_.LocalName -eq "footnote" -and $_.GetAttribute("id", $W) -eq $fid }
    $text = (($fn.ChildNodes | Where-Object { $_.LocalName -eq "p" } | ForEach-Object { Convert-Inline $_ $fnLinks }) -join " ").Trim()
    [void]$body.Add("  <li id=""fn$n"">$text <a href=""#fnref$n"" class=""fnback"" aria-label=""Back to text"">&#8617;</a></li>")
  }
  [void]$body.Add("</ol>")
  [void]$body.Add("</section>")
}

# ---------- Credits ----------

foreach ($g in $creditGroups) {
  $cls = if ($g.Paras.Count) { "credits__group credits__group--wide" } else { "credits__group" }
  [void]$credits.Add("<div class=""$cls"">")
  [void]$credits.Add("<h3>$(Esc $g.Title)</h3>")
  if ($g.Items.Count) {
    [void]$credits.Add("<ul>")
    foreach ($i in $g.Items) { [void]$credits.Add("  <li>$i</li>") }
    [void]$credits.Add("</ul>")
  }
  foreach ($p in $g.Paras) { [void]$credits.Add("<p>$p</p>") }
  [void]$credits.Add("</div>")
}

# ---------- Write into proceedings.html ----------

function Set-Region([string]$html, [string]$name, $lines, [string]$indent) {
  $begin = "<!-- BEGIN:$name -->"; $end = "<!-- END:$name -->"
  $a = $html.IndexOf($begin); $b = $html.IndexOf($end)
  if ($a -lt 0 -or $b -lt $a) { throw "Marker $begin / $end not found in proceedings.html" }
  $content = ($lines | ForEach-Object { if ($_) { $indent + $_ } else { "" } }) -join "`n"
  return $html.Substring(0, $a + $begin.Length) + "`n" + $content + "`n" + $indent + $html.Substring($b)
}

$html = [IO.File]::ReadAllText($page, $utf8)
$html = Set-Region $html "TOC" (@("<ol class=""toc__list"">") + $toc + @("</ol>")) "          "
$html = Set-Region $html "BODY" $body "          "
$html = Set-Region $html "CREDITS" $credits "            "
[IO.File]::WriteAllText($page, $html.Replace("`r`n", "`n"), $utf8)

Write-Host "Updated proceedings.html: $(($body | Where-Object { $_ -like '<h2*' }).Count) chapters, $(($body | Where-Object { $_ -like '<h3*' }).Count) sections, $($footnoteOrder.Count) footnote(s), $($creditGroups.Count) credit groups."
