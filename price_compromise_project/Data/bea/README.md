# BEA data manifest

Downloaded on 2026-06-28 from official BEA public download endpoints.

## Input-Output Accounts

Source page: https://www.bea.gov/industry/input-output-accounts-data

Raw ZIP files:
- `raw/SUPPLY-USE.zip`
- `raw/MAKE-USE-IMPORTS_BEFORE_REDEFINITIONS.zip`
- `raw/TOTAL_AND_DOMESTIC_REQUIREMENTS.zip`

Unzipped folders:
- `raw/unzipped/SUPPLY-USE/`
- `raw/unzipped/MAKE-USE-IMPORTS_BEFORE_REDEFINITIONS/`
- `raw/unzipped/TOTAL_AND_DOMESTIC_REQUIREMENTS/`

Likely files for the 2019 fixed IO network:
- `raw/unzipped/SUPPLY-USE/Use_Summary.xlsx`
- `raw/unzipped/SUPPLY-USE/Use_SUT_Detail.xlsx`
- `raw/unzipped/MAKE-USE-IMPORTS_BEFORE_REDEFINITIONS/IOUse_Before_Redefinitions_PRO_Summary.xlsx`
- `raw/unzipped/MAKE-USE-IMPORTS_BEFORE_REDEFINITIONS/IOUse_Before_Redefinitions_PRO_Detail.xlsx`
- `raw/unzipped/MAKE-USE-IMPORTS_BEFORE_REDEFINITIONS/ImportMatrices_Before_Redefinitions_Summary.xlsx`
- `raw/unzipped/TOTAL_AND_DOMESTIC_REQUIREMENTS/IxI_TR_Summary.xlsx`
- `raw/unzipped/TOTAL_AND_DOMESTIC_REQUIREMENTS/IxI_Domestic_Summary.xlsx`

## GDP by Industry

Source page: https://www.bea.gov/itable/gdp-by-industry

Raw files:
- `raw/GdpByInd.zip`
- `raw/GrossOutput.xlsx`
- `raw/IntermediateInputs.xlsx`

Unzipped folder:
- `raw/unzipped/GdpByInd/`

Key sheets:
- `GrossOutput.xlsx`, sheet `TGO104-A`: annual chain-type price indexes for gross output by industry.
- `IntermediateInputs.xlsx`, sheet `TII104-A`: annual chain-type price indexes for intermediate inputs by industry.

## Concordance

Raw file:
- `raw/BEA-Industry-and-Commodity-Codes-and-NAICS-Concordance.xlsx`

Use:
- Match BEA industry and commodity codes to NAICS/BLS industry definitions.

