# Crossroads Convening website

The site for **Crossroads: A Transportation Equity and Justice Convening**, served by GitHub Pages at [crossroadsconvening.org](https://crossroadsconvening.org).

It is a plain static site: no build step and no dependencies.

```
index.html            the home page (one scrolling page)
proceedings.html      the 2026 conference report
assets/css/styles.css styles
assets/js/main.js     mobile menu and click-to-play videos
assets/img/           logos, banner photo, site icon (mark.svg)
tools/serve.ps1       local preview server (Windows PowerShell)
tools/build-proceedings.ps1  converts the proceedings Word file into proceedings.html
```

## Editing content

Everything is in `index.html`, split into commented sections (`HERO`, `WHAT'S NEXT / TIMELINE`, `ABOUT`, `2026 ARCHIVE`, `SPONSORS`, `STAY IN TOUCH`).

**Timeline:** each stop is an `<li class="stop">` in the `route` list.
- `stop--done` marks a past stop (filled dot)
- `stop--now` marks the current stop (yellow, pulsing); stops after it show a dashed track
- `stop--terminal` marks the last stop

**Sponsors:** add an `<li>` to `sponsor-grid` and put the logo in `assets/img/`.

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

## Moving crossroadsconvening.org from Google Sites

Do this only once the GitHub Pages version looks right. The old site stays up until DNS changes.

1. **Add the custom domain in GitHub.** Under **Settings → Pages → Custom domain**, enter `crossroadsconvening.org` and save. GitHub commits a `CNAME` file to the repo.
   (Don't add a `CNAME` file before this: it makes the `github.io` preview redirect to the domain, which still shows the old Google site.)
2. **Remove the domain from Google Sites.** In the Google Sites editor: **Settings → Custom domains**, remove `crossroadsconvening.org`.
3. **Update DNS at your domain registrar.** Remove the old records pointing to Google (`ghs.googlehosted.com` or Google IPs) and add:

   | Type  | Name  | Value                 |
   |-------|-------|-----------------------|
   | A     | @     | 185.199.108.153       |
   | A     | @     | 185.199.109.153       |
   | A     | @     | 185.199.110.153       |
   | A     | @     | 185.199.111.153       |
   | AAAA  | @     | 2606:50c0:8000::153   |
   | AAAA  | @     | 2606:50c0:8001::153   |
   | AAAA  | @     | 2606:50c0:8002::153   |
   | AAAA  | @     | 2606:50c0:8003::153   |
   | CNAME | www   | `<owner>.github.io`   |

4. Wait for DNS to update (minutes to a few hours). When GitHub shows the domain check as passing, turn on **Enforce HTTPS** in **Settings → Pages**.
5. Optional but recommended: [verify the domain](https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site/verifying-your-custom-domain-for-github-pages) for your GitHub account or organization so nobody else can claim it.
