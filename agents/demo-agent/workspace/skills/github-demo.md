# GitHub Demo Skill

Use this repo-local workflow when the request is about GitHub issues:

1. Run `./tools/github-issue-list-public.sh OWNER/REPO 5` to fetch a current public issue sample.
2. If the user wants to create an issue, check whether `gh auth status` succeeds first.
3. If auth is valid, run `./tools/github-issue-create.sh OWNER/REPO "title" "body"`.
4. If auth is not valid, explain the missing step instead of guessing.
