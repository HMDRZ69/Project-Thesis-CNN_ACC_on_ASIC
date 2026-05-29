# Weekly Progress Report – Week 05  
**Date:** December 5, 2025

### Accomplished This Week
- Established a clean and scalable GitHub repository structure to support ongoing weekly progress reporting (up to week 03 at the time of setup):
  - Created dedicated folders: `Cadence/Xcelium/Genus/Innovus`, `simulation/`, `weekly-reports/`
  - Standardized file naming conventions (underscores instead of spaces)
- Created and organized the main `README.md` file to serve as the project entry point:
  - Added project title, overview, thesis context, and links to weekly reports
  - Included a progress table with direct links to each weekly report Markdown file
- Documented and summarized tasks and achievements from the initial weeks (weeks 01–03):
  - Consolidated early progress notes, code snippets, and simulation results for better traceability
- Verified repository accessibility and rendering of Markdown files, images, and code blocks on GitHub

### Results & Outputs
- Fully functional public repository with improved navigation and documentation  
  Repository link: https://github.com/HMDRZ69/Project-Thesis-CNN_ACC_on_ASIC  
  (README now provides quick access to all weekly reports and project overview)

### Key Learnings / Insights
- A well-structured README and consistent folder layout significantly improve readability and maintainability of long-term academic projects
- Early investment in proper repository organization prevents major refactoring later
- GitHub Markdown rendering handles code blocks, tables, and embedded images reliably when paths are correct

### Challenges & Blocking Points
- Initial git commit failed due to unset user.name and user.email  
  → **Solution:** Set global git config: `git config --global user.name "Your Name"` and `user.email`
- Push to GitHub failed due to missing remote origin or incorrect branch name (main vs master)  
  → **Solution:** Added remote: `git remote add origin <url>` and set branch: `git branch -M main`
- Error when copying screenshot files to simulation folder in PowerShell because of spaces in filenames  
  → **Solution:** Renamed screenshot files to remove spaces (e.g., `half adder waveform.png` → `half_adder_waveform.png`)

### Plan for Next Week
- Continue and update the GitHub repository with weekly reports on a regular basis
- Review and check the PDK content (Process Design Kit) provided for IHP SG13G2 technology