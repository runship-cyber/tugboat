# 🚢 Tugboat

Use Tugboat when your team needs to collaborate on a Markdown file that relates to a specific issue on GitHub. Apply a label of your choice to a particular issue, and Tugboat automatically creates a pull request with a template Markdown file that's ready for you to edit.

## Using Tugboat

Tugboat is a workflow for GitHub Actions. To learn about GitHub Actions, see "[About GitHub Actions](https://help.github.com/en/actions/getting-started-with-github-actions/about-github-actions)". For more information about billing for GitHub Actions, see "[About billing for GitHub Actions](https://help.github.com/en/actions/getting-started-with-github-actions/about-github-actions#about-billing-for-github-actions)".

1. Add _tugboat.yml_ and _.github/workflows/tugboat_ to _.github/workflows_ in the repository where you want to label issues for Tugboat.

2. In the repository with the workflow, apply Tugboat's label to an issue. By default, the label is `tugboat`.

3. Tugboat comments on the issue where you applied the label when the pull request with the Markdown file is ready.

## Customizing Tugboat

You can edit the following files to change how Tugboat behaves.

- [_.github/workflows/tugboat.yml_](.github/workflows/tugboat.yml) contains [environment variables](.github/workflows/tugboat.yml#L17-L138) that determine which label Tugboat uses, where Tugboat creates its pull requests, and more.

- [_.github/workflows/tugboat/pull_body.md_](.github/workflows/tugboat/pull_body.md) contains text that appears in the body of the initial comment of Tugboat's pull request.

- [_.github/workflows/tugboat/tugboat.md_](.github/workflows/tugboat/tugboat.md) is a template for the Markdown file that Tugboat creates for the pull request.

## Getting help

Need help? Want to report a bug or request a feature? [Open an issue](https://github.com/mattpollard/tugboat/issues/new).
