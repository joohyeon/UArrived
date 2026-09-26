# core/ — shared graph model (owned by BOTH feature leads)

Nodes and edges that more than one feature needs: `Student` (profile), shared enums/types, and the
typed edges that connect a student to journey tasks (`Applies`, `Prerequisite`, `Completed`) and to
marketplace listings (`Wants`, `Matches`). Feature-specific nodes live in the feature folder.

**Changing anything here needs approval from both Feature A and Feature B owners** (CODEOWNERS).
Land contract changes as their own small PR *before* the feature work that depends on them.
