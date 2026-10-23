# Crossroads Convening website

The site for **Crossroads: A Transportation Equity and Justice Convening**, served by GitHub Pages at [crossroadsconvening.org](https://crossroadsconvening.org).

It is a plain static site: no build step and no dependencies.

```
index.html            home page: objective and goals, who we welcome, what's next, stay in touch
2026.html             the 2026 Convening: overview, recordings, program, sponsors
proceedings.html      the 2026 conference report
assets/css/styles.css styles
assets/js/main.js     mobile menu and click-to-play videos
assets/img/           logos, banner photo, site icon (mark.svg)
tools/serve.ps1       local preview server (Windows PowerShell)
tools/build-proceedings.ps1  converts the proceedings Word file into proceedings.html
```

## Editing content

Each page is split into commented sections. `index.html` has `HERO`, `ABOUT / OBJECTIVE`, `WHO WE WELCOME / WHO WE ARE`, `WHAT'S NEXT / TIMELINE`, `2026 CONVENING` and `STAY IN TOUCH`; `2026.html` has `OVERVIEW`, `RECORDINGS & PROGRAM` and `SPONSORS`.

**Timeline:** each stop is an `<li class="stop">` in the `route` list on the home page. Add or remove stops freely; the line resizes to fit.
- `stop--done` marks a past stop (filled dot)
- `stop--now` marks the current stop (yellow, pulsing); stops after it show a dashed track
- `stop--terminal` marks the last stop

**Sponsors:** add an `<li>` to `sponsor-grid` in `2026.html` and put the logo in `assets/img/`.

## Updating the proceedings

The text of `proceedings.html` is generated from the Word file *Crossroads Convening Summary.docx*. Don't edit the report text in the HTML. Instead, edit the Word file, download it as `.docx`, and run:

```powershell
powershell -ExecutionPolicy Bypass -File tools\build-proceedings.ps1 -Docx "path\to\Crossroads Convening Summary.docx"
```

The script replaces only the content between the `BEGIN`/`END` comments in `proceedings.html` (contents list, report body, credits), so the rest of the page can be edited by hand. It maps Word's Heading 1/2/3 styles to chapters, sections and sub-headings; keeps bold, italics, links, bulleted and numbered lists, and footnotes; and turns the front matter (organizing committee, notetakers, acknowledgments) into the "About this report" section.

## Previewing locally

```powershell
powershell -ExecutionPolicy Bypass -File tools\serve.ps1
```

Then open http://localhost:8080. Any other static server works too (for example `python -m http.server`).

## Publishing on GitHub Pages

1. Push this folder to a GitHub repository.
2. In the repository, go to **Settings → Pages**. Under **Build and deployment**, choose **Deploy from a branch**, branch `main`, folder `/ (root)`.
3. The site is then live at `https://<owner>.github.io/<repo>/`. Check it there before moving the domain.

## Moving crossroadsconvening.org to GitHub Pages

### How the domain works today (checked October 2026)

- The domain's DNS is hosted at **NearlyFreeSpeech.NET (NFSN)** (nameservers `ns.phx5.nearlyfreespeech.net` and `ns.phx6.nearlyfreespeech.net`).
- `crossroadsconvening.org` and `www.crossroadsconvening.org` both point at a small NFSN site named **crossroads** (`crossroads.nfshost.com`), which redirects every visitor to `https://sites.google.com/view/crossroads-convening`.
- Google Sites has no custom domain configured, so nothing needs to change in Google Sites.

All of the DNS work happens in the NFSN account that manages the domain. Do this only once the GitHub Pages version looks right; the old redirect keeps working until the DNS changes.

### Steps

1. **Verify the domain with GitHub (recommended).** This stops anyone else from claiming it on GitHub Pages. In your GitHub profile, go to **Settings → Pages → Add a domain**, enter `crossroadsconvening.org`, and GitHub gives you a TXT record. Add it in NFSN under **Domains → crossroadsconvening.org → Manage DNS**, then click **Verify** in GitHub. ([GitHub docs](https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site/verifying-your-custom-domain-for-github-pages))

2. **Set the custom domain in GitHub.** In the repository, go to **Settings → Pages → Custom domain**, enter `crossroadsconvening.org` and save. GitHub commits a `CNAME` file to the repo. After this, the `github.io` address forwards to the domain, which still shows the Google Site until step 3 is done.
   (Don't add a `CNAME` file by hand before you're ready to switch, for the same reason.)

3. **Change the DNS at NFSN.**
   1. **Detach the domain from the redirect site.** In NFSN, go to **Sites → crossroads → Site Names & Aliases** and remove `crossroadsconvening.org` and `www.crossroadsconvening.org`. NFSN manages DNS records automatically for domains attached to a site, so skipping this may bring the old records back.
   2. **Remove the old records** under **Domains → crossroadsconvening.org → Manage DNS**:

      | Type  | Name    | Value                    |
      |-------|---------|--------------------------|
      | A     | (blank) | 208.94.116.113           |
      | AAAA  | (blank) | 2607:ff18:80::82b2       |
      | CNAME | www     | crossroads.nfshost.com   |

   3. **Add the GitHub Pages records:**

      | Type  | Name    | Value                 |
      |-------|---------|-----------------------|
      | A     | (blank) | 185.199.108.153       |
      | A     | (blank) | 185.199.109.153       |
      | A     | (blank) | 185.199.110.153       |
      | A     | (blank) | 185.199.111.153       |
      | AAAA  | (blank) | 2606:50c0:8000::153   |
      | AAAA  | (blank) | 2606:50c0:8001::153   |
      | AAAA  | (blank) | 2606:50c0:8002::153   |
      | AAAA  | (blank) | 2606:50c0:8003::153   |
      | CNAME | www     | aakarner.github.io    |

4. **Turn on HTTPS.** DNS usually updates within minutes to a few hours. When the domain check passes in the repository's **Settings → Pages**, tick **Enforce HTTPS**. Until GitHub issues the certificate, `https://` visitors may briefly see a security warning.

5. **Clean up later.** Once the new site loads on the domain, you can delete the NFSN **crossroads** site and unpublish the Google Site. Keeping them for a week or two as a fallback is harmless.

To check the switch from a terminal (PowerShell):

```powershell
Resolve-DnsName crossroadsconvening.org
Resolve-DnsName www.crossroadsconvening.org
```

The first should return the four `185.199.x.153` addresses, and the second should show `aakarner.github.io`.
