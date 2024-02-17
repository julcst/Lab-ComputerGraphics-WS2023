# Computer Graphics Report Template

Version 2.0.0

Patrick Stotko (stotko@cs.uni-bonn.de)  
Lukas Bode (lbode@cs.uni-bonn.de)

## Requirements

Installed LaTeX distribution, e.g.:

- Linux : TeXLive
- Windows : MikTeX, TeXLive
- macOS : MacTeX

We use *pdflatex* and *biber* as the compilers for .tex and .bib files. Make sure that both are installed.

THERE IS NO GUARANTEE THAT THIS TEMPLATE ALSO WORKS WITH OTHER COMPILERS (BIBTEX WILL NOT WORK!).

## Structure

This template includes an english as well as a german version which can be switched by setting language option at the top of the main file.

In both cases you have to set thesis type, author, matriculation number, and title.

Add the literature you need to literature.bib regardless of the language you use.

## Building

You can compile this template using one of the following methods:

- Commandline:

    ```
    pdflatex report
    biber report
    pdflatex report
    pdflatex report
    ```

- TeXStudio (recommended)

    - Set pdflatex as the default TeX and biber as the default bibliography compiler in the settings
    - Compile report.tex (TexStudio will care about executing pdflatex and biber, SOMETIMES BUGGY AND MUST BE CALLED MANUALLY)

Any other TeX IDE will also work. Make sure it executes pdflatex and biber.

## Troubleshooting

In cases you have trouble using this template, check the following common problems:

- pdflatex complains about unknown option giveninits when loading biblatex --> Upgrade your biblatex package

If this does not solve your problem or you have questions, please contact the authors of this template.