# Weekly Progress Report – Week 09  
**Date:** January 18, 2026

### Accomplished This Week
- Diagnosed empty Library Manager in Cadence Virtuoso:
  - Identified that the active `cds.lib` file was not pointing to the IHP SG13G2 PDK libraries
- Verified the SG13G2 PDK installation integrity and traced its dependency chain:
  - Confirmed correct extraction and contents of the PDK directory
  - Analyzed the role of the `IHP_TECH` environment variable in library mapping
- Permanently corrected the `IHP_TECH` environment variable:
  - Set it to point to the local SG13G2 PDK installation path
- Updated and activated the correct `cds.lib` configuration:
  - Included SG13G2 PDK libraries in a safe, non-destructive manner
  - Avoided overwriting system-wide or shared cds.lib files
- Successfully launched Cadence Virtuoso and verified:
  - All relevant SG13G2 libraries now appear correctly in the Library Manager
  - No missing references or initialization errors

### Results & Outputs
- Cadence Virtuoso environment now fully recognizes the IHP SG13G2 PDK
- Library Manager displays expected technology libraries, device symbols, PCells, and standard cells
- Environment is stable and ready for creating project-specific design libraries

### Key Learnings / Insights
- Cadence tools rely heavily on environment variables (`IHP_TECH`, `CDS_LIB_DIR`, etc.) for PDK discovery — small misconfigurations cause complete library invisibility
- Always use project-local or user-specific `cds.lib` overrides instead of modifying global/shared files
- Verifying Library Manager contents immediately after configuration changes saves hours of downstream debugging

### Challenges & Blocking Points
- Library Manager showed empty/no libraries due to incorrect `cds.lib` linkage to SG13G2 PDK  
  → **Solution:** Updated `IHP_TECH` variable and corrected/active `cds.lib` file → libraries now visible

### Plan for Next Week
- Create a new project design library linked to the SG13G2 technology
- Verify correct technology attachment and layer mapping in the new library
- Define the initial design scope and constraints for the CNN accelerator (block-level view)
- Prepare the design environment for standard-cell–based digital implementation