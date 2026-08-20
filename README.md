# Ethnic Inequalities in Mental Well-Being at the Onset of COVID-19

**Evidence from the UK**

> **Status:** MSc thesis (2026)
> **Language:** Stata · **Data:** Understanding Society (SN 6614) & COVID-19 Study (SN 8644)


---

## Overview

Did ethnic minority groups in the UK suffer larger declines in mental well-being when the
COVID-19 pandemic began? This project answers that question using longitudinal survey data
covering the 2019 pre-pandemic baseline and the first months of the pandemic.

The analysis compares the majority in the UK against two alternative minority definitions:

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

## Research design

| Component | Approach |
|---|---|
| Outcome | GHQ-12 mental well-being score |
| Comparison | 2019 pre-pandemic baseline vs. April 2020 |
| Method 1 | Oaxaca–Blinder decomposition of the change in GHQ-12 |
| Method 2 | Event study tracing ethnic gaps before and after pandemic onset |
| Groups | White majority vs. BAME; White majority vs. BIP |


## Repository structure

```
Thesis2026/
├── do/
│   ├── 00_Combine Panel.do                             # Combine 2019 baseline and April 2020
│   ├── 01_Equation 2.do                                # Standardize GHQ-12 likert score and implement COVID weighted.
│   ├── 02_(BIP)Add all the factors.do                  # Sample selection and Adding all factors
│   ├── 02_Table 1                                      # Changes in GHQ-12 Mental Well-Being by Ethnic Group
│   ├── 3(A-F)(BIP)_.do                                 # Univariate association for each factors (Find in Appendix A)
│   ├── 04_decomp.do                                    # Oaxaca–Blinder decompositions
│   ├── 05_decomposition table.do                       # Generate decomposition tables
│   ├── 06_Appendix(C1-2)(BIP).do                       # Appendix
│   ├── Proportion file                                 # Table 2 to 7 in section 2
│   ├── Event study file                                # Figure 2 to 5
│   ├── Figure 1  file                                  # Descriptive Trends in Mental Well-Being among BAME and White Majority Respondents
├── out/                                                # Tables and figures
│   ├── Tables file                                     # Table 1 to 7
│   ├── Descriptive trends file                         # Descriptive trends by different ethnic categories
│   ├── Decomposition file                              # Decomposition results
│   ├── Event study file                                # Event study results
│   ├── Appendix file                                   # Appendix
│   ├── Figure 1 file                                   # 
├── ipynb/                                              # Ipynb files transfer results to the paper
│   ├── Change in GHQ(SE-Latest).ipynb                  # Match Descriptive trends file
│   ├── Decomposition tables.ipynb                      # Match Decomposition file
│   ├── Event study file                                # Event study results
│   ├── Tables file                                     # Table 1 to 7 
│   ├── Appendix file                                   # Appendix



## Data

This project uses two restricted-access datasets from the UK Data Service:

| Study | Title | Access level |
|---|---|---|
| **SN 6614** | Understanding Society: UK Household Longitudinal Study | Safeguarded (EUL) |
| **SN 8644** | Understanding Society: COVID-19 Study | Safeguarded (EUL) |

**No data are included in this repository.** Both datasets are Safeguarded and governed by
the UK Data Service End User Licence, which prohibits redistribution of the data or of any
dataset derived from them. Only aggregated statistical output (tables and figures in `out/`)
is published here.