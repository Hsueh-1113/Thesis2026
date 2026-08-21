# Ethnic Inequalities in Mental Well-Being at the Onset of COVID-19

**Evidence from the UK**

> **Status:** MSc thesis (2026) · **Language:** Stata · **Data:** Understanding Society (SN 6614) & COVID-19 Study (SN 8644)

---

## Overview

Did ethnic minority groups in the UK suffer larger declines in mental well-being when the
COVID-19 pandemic began? This project answers that question using longitudinal survey data
covering the 2019 pre-pandemic baseline and the first months of the pandemic.

The analysis compares the white majority (WM) in the UK against two alternative minority
definitions:

- **BAME** — a broad Black, Asian, and other minority ethnic category
- **BIP** — a narrower group of Bangladeshi, Indian, and Pakistani respondents

**Main findings.** The broad BAME–WM comparison shows no strong evidence of a large or
persistent widening of the mental well-being gap. A larger, statistically significant gap
emerges once the minority group is restricted to BIP respondents. Decompositions point to
age composition and economic vulnerability — particularly employment and financial
conditions — as important correlates of the gap. Event-study estimates show a sharp widening
of the BIP–WM gap in the early pandemic months, followed by partial but incomplete
convergence.

These results highlight how sensitive conclusions about health inequality are to the choice
of ethnic categorisation: aggregating minority groups into a single BAME category masks
substantial heterogeneity.

---

## Research design

| Component  | Approach                                                        |
| ---------- | --------------------------------------------------------------- |
| Outcome    | GHQ-12 mental well-being score                                  |
| Comparison | 2019 pre-pandemic baseline vs. April 2020                       |
| Method 1   | Oaxaca–Blinder decomposition of the change in GHQ-12            |
| Method 2   | Event study tracing ethnic gaps before and after pandemic onset |
| Groups     | White majority vs. BAME; white majority vs. BIP                 |

---

## Repository structure

Most analysis steps are estimated twice — once for the BAME definition and once for BIP —
which is why several do-files come in pairs.

```
Thesis2026/
├── do/                                  # Stata analysis code
│   ├── 00_Combine Panel .do             # Combine 2019 baseline and April 2020 waves
│   ├── 01_Equation 2.do                 # Standardise GHQ-12 Likert score, apply COVID weights
│   ├── 02_Add all the factors.do        # Sample selection and covariates (BAME)
│   ├── 02_BIP_Add all the factors.do    # Sample selection and covariates (BIP)
│   ├── 02_Table1.do                     # Table 1 — change in GHQ-12 by ethnic group
│   ├── 3A … 3F run for ….do             # Univariate association for each factor group
│   │                                    #   (employment, financial, housing, health,
│   │                                    #   household composition, demographics);
│   │                                    #   _BIP variants alongside — see Appendix A
│   ├── 04_Bame Decompose.do             # Oaxaca–Blinder decomposition (BAME)
│   ├── 04_bip Decompose.do              # Oaxaca–Blinder decomposition (BIP)
│   ├── 05_decomposition table.do        # Assemble decomposition tables
│   ├── 06_Appendix_BAME.do              # Appendix C1–C2 (BAME)
│   ├── 06_Appendix_BIP.do               # Appendix C1–C2 (BIP)
│   ├── Event study/                     # Event-study specifications:
│   │                                    #   main (BAME), BIP, BIP by finances, BIP by sex
│   ├── Figure 1/                        # Seasonal adjustment, weighting, and Figure 1
│   └── Proportion/                      # Group proportions by factor — Tables 2–7
├── out/                                 # Generated tables and figures
│   ├── Tables/                          # Tables 1–7
│   ├── Descriptive trends/              # Trends by ethnic categorisation
│   ├── Decomposition/                   # Decomposition results (.tex tables, tidy .csv)
│   ├── Event study/                     # Figures 2–5
│   └── Appendix/                        # BAME and BIP subfolders
├── ipynb/                               # Notebooks formatting results for the paper
│   ├── Change in GHQ(SE-Latest).ipynb   # Descriptive trends
│   ├── Decomposition tables.ipynb       # Decomposition tables
│   ├── Tables/                          # Tables 1–7
│   ├── Event study/                     # Event-study output
│   └── Appendix/                        # Appendix output
├── Ethnic_Inequalities_in_Mental_Health_at_the_Onset_of_the_COVID_19_Pandemic__Empirical_Evidence_from_the_UK.pdf
├── .gitignore
└── README.md
```

**Order of execution:** `00` → `01` → `02` → `3A`–`3F` → `04` → `05` → `06`, then the
`Event study/`, `Figure 1/` and `Proportion/` folders. Output is written to `out/` and
formatted for the paper in `ipynb/`.

---

## Data

This project uses two restricted-access datasets from the UK Data Service:

| Study | Title | Access level |
| --- | --- | --- |
| **SN 6614** | Understanding Society: UK Household Longitudinal Study | Safeguarded (EUL) |
| **SN 8644** | Understanding Society: COVID-19 Study | Safeguarded (EUL) |

**No data are included in this repository.** Both datasets are Safeguarded and governed by
the UK Data Service End User Licence, which prohibits redistribution of the data or of any
dataset derived from them. Only aggregated statistical output (tables and figures in `out/`)
is published here.
