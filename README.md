# md-to-pdf-upload-action

## Usage in your action

### Installation

```yml
- name: Generate PDFs
  uses: opf/md-to-pdf-upload-action@v1
  with:
    # md-to-pdf config file, relative to the root of the repository
    config: "./md-to-pdf.config.yml" 
    # md-to-pdf styling folder, relative to the root of the repository
    stylings: "./styling/" 
    # the nextcloud username for the upload
    nextcloud-user: "pdf-bot-user"
    # the nextcloud App key for the uploading user
    nextcloud-app-access-key: "the secret app key; do not place here, use github secrets"
    # the root folder on the nextcloud server where the files should be uploaded
    nextcloud-upload-path: "https://nextcloud.example.com/remote.php/dav/files/pdf-bot-user/some-example-path/upload-folder/"
```

### Full example

```yml
name: Generate PDFs

on:
  workflow_dispatch:

jobs:
  generate:
    runs-on: [ ubuntu-latest ]
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          ref: "main"

      - name: Generate PDFs
        uses: opf/md-to-pdf-upload-action@v1
        with:
          config: "./md-to-pdf.config.yml"
          stylings: "./styling/" 
          nextcloud-user: ${{ secrets.NEXTCLOUD_USERNAME }}
          nextcloud-app-access-key: ${{ secrets.NEXTCLOUD_APP_ACCESS_KEY }}
          nextcloud-upload-path:  ${{ secrets.NEXTCLOUD_UPLOAD_PATH }}
```

# Howto

* Create a stylings structure for md-to-pdf file in the your repository, 
  see [md-to-pdf styling](https://github.com/opf/md-to-pdf/blob/main/docs/STYLING.md)
* Create a `md-to-pdf.config.yml` file in the your repository. 

If you don't use the repository root folder, you need to configure the locations to the styling folder and the yml file in your action config. 

```yml
  uses: opf/md-to-pdf-upload-action@v1
  with:
    config: ".github/md-to-pdf-example-path/md-to-pdf.config.yml" # relative to the root of the repository
    stylings: ".github/md-to-pdf-example-path/styling/" # relative to the root of the repository
```

> [!NOTE]
> All destination folders on Nextcloud must already exists, this action does not create folders. 
> 
> The action will overwrite existing files with the same name in the destination folder on Nextcloud. 
> 
> The action will not delete files in the destination folder on Nextcloud.


# Generator configuration

## Smallest configuration with all mandatory values

```yml
- documents:
    - source: demo/demo.md
      destination: demo-on-server/demo-file-on-server-1.pdf
      styling: demo-styling
```

## Explained sample configuration

```yml
# you can create different groups, this is group 1
- default: # default values for all documents in this group
    styling: demo-styling # name of file in the stylings folder WITHOUT extension (optional if all stylings are set in documents)
    pdf_language: de # optional, language to be used in the PDF (Hyphenation)
    pdf_footer_3: Seite <page> von <total> # optional, localized footer text
  documents:
    - source: demo/demo-de.md # mandatory, path to the markdown file, relative to the repository(!) root
      destination: demo-path-on-server/de/demo-file-on-server-de.pdf # mandatory, path and filename to the destination on the server
      styling: demo-styling # optional, overwrite default styling, if needed
      pdf_footer: Demo-Datei Footer  # optional, set a footer text for this document

# group 2 same as group 1 but with different language
- default:
    styling: demo-styling
    pdf_language: en
    pdf_footer_3: Page <page> of <total>
  documents:
    - source: demo/demo-en.md
      destination: demo-path-on-server/en/demo-file-on-server-en.pdf
      pdf_footer: Demo File Footer

# group 3 with default stylings value 
- default:
    styling: demo-styling
  documents:
    - source: demo/demo-3.md
      destination: demo-file-on-server-3.pdf
    - source: demo/demo-4.md
      destination: demo-file-on-server-4.pdf

# group 4 without default values
- documents:
    - source: demo/demo-5.md
      destination: demo-file-on-server-5.pdf
      styling: demo-styling
    - source: demo/demo-6.md
      destination: demo-file-on-server-6.pdf
      styling: demo-styling-2
```

For values starting with `pdf_` see [md-to-pdf frontmatter](https://github.com/opf/md-to-pdf/blob/main/docs/FRONTMATTER.md) for available options.

