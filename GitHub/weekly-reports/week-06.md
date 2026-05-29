# Weekly Progress Report – Week 06  
**Date:** December 12, 2025

### Accomplished This Week
- Finalized and completed weekly progress reports up to Week 05:
  - Ensured consistent formatting, added code snippets, simulation screenshots, and challenge/solution sections
  - Verified correct rendering of Markdown files, tables, and embedded images on GitHub
- Verified availability of the IHP SG13G2 Process Design Kit (PDK) on the university shared storage
- Attempted local installation and configuration of the IHP SG13G2 PDK for the Cadence environment
- Initiated a full filesystem search across shared and local storage to locate the complete SG13G2 PDK archive

### Results & Outputs
- Weekly reports (01–05) now fully documented, structured, and publicly accessible on GitHub
- Confirmed presence of SG13G2-related directories on university storage, though top-level content was incomplete
- Identified the specific archive file: `SG13G2_618_rev1.3.2.tar.gz`

### Key Learnings / Insights
- Proper PDK setup is one of the most critical and time-consuming early steps in an ASIC design flow
- University shared storage layouts can differ significantly from documentation or expected structures
- Keeping weekly documentation up-to-date prevents knowledge loss and makes progress visible

### Challenges & Blocking Points
- Discovered that the top-level `PDK_IHP` directory was empty or incomplete.
→ **Solution** Identified a mismatch between the expected PDK storage layout and the actual filesystem organization.

### Plan for Next Week
- Extract the IHP SG13G2 PDK into user HOME directory
- Create a dedicated local PDK directory in HOME
- Copy the SG13G2 PDK archive to the local workspace
- Extract `SG13G2_618_rev1.3.2.tar.gz` for further Cadence configuration