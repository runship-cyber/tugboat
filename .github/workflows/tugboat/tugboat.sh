#!/bin/bash

# ------------------------------------------------------------------- Variables

exit_code=1
step_status=running

json_scratch_file_path=/home/runner/work/_temp/request.json
pull_body_scratch_file_path=/home/runner/work/_temp/pull_body.md

workflow_repository_clone_path=$GITHUB_WORKSPACE/workflow
workflow_repository_url=https://github.com/$GITHUB_REPOSITORY

issue_number_with_leading_zeroes=$(printf "%06d" $ISSUE_NUMBER)

branch_name=$GITHUB_REPOSITORY/$LABEL/issue-$issue_number_with_leading_zeroes

markdown_repository_api_url=https://api.github.com/repos/$MARKDOWN_REPOSITORY
markdown_repository_url=https://github.com/$MARKDOWN_REPOSITORY
markdown_file_path=$MARKDOWN_PATH/issue-$issue_number_with_leading_zeroes.md
markdown_file_edit_url=$markdown_repository_url/edit/$branch_name/$markdown_file_path
markdown_file_view_url=$markdown_repository_url/blob/$branch_name/$markdown_file_path

pull_title="$PULL_TITLE_PREFIX '$ISSUE_TITLE'"

# ------------------------------------------------------------------- Functions

post_to_api() {
  endpoint_url=$1
  json_file_path=$2

  >&2 echo ℹ️ POSTing to $endpoint_url with JSON payload of $(cat $json_file_path)

  curl \
    --silent \
    --write-out "HTTPSTATUS:%{http_code}" \
    --request POST \
    --header "authorization: Bearer $ACCESS_TOKEN" \
    --url $endpoint_url \
    --data-binary @$json_file_path

  rm $json_file_path
}

parse_api_response_code() {
  response=$1

  echo "$response" | tr -d '\n' | sed -e 's/.*HTTPSTATUS://'
}

parse_api_response_body() {
  response=$1

  echo "$response" | sed -e 's/HTTPSTATUS\:.*//g' | jq -r .
}

# ------------------------------------------------------------------------ Main

if [ -f "$markdown_file_path" ]; then
  exit_code=0
  step_status=skipped

  >&2 echo ℹ️ $markdown_file_path exists in $MARKDOWN_REPOSITORY. Skipping step...
else
  if [ -n "$(git ls-remote --heads origin $branch_name)" ]; then
    exit_code=0
    step_status=skipped

    >&2 echo ℹ️ $branch_name branch exists for $MARKDOWN_REPOSITORY. Skipping step...
  else

    # ----------------------------------- Stage changes in $MARKDOWN_REPOSITORY

    base_branch_name=$(git rev-parse --abbrev-ref HEAD)

    git config --local user.email $GIT_USER_EMAIL
    git config --local user.name $GIT_USER_NAME

    git checkout -b $branch_name

    mkdir -p $MARKDOWN_PATH

    cp $workflow_repository_clone_path/$MARKDOWN_TEMPLATE_FILE_PATH \
       $markdown_file_path

    git add $markdown_file_path
    git commit -m "Create Markdown file"
    git push -u origin HEAD

    if [ -n "$(git ls-remote --heads origin $branch_name)" ]; then
      pushed_branch=true
    fi

    # ----------------------------------------------------- Create pull request

    # Prepare the pull request's body.

    cat << EOF > $pull_body_scratch_file_path
$([ "$PULL_CLOSES_ISSUE" == 'true' ] && echo Closes $ISSUE_URL.)

$PULL_BODY_INTRODUCTION

You can [edit]($markdown_file_edit_url) or [view]($markdown_file_view_url) the Markdown file here on GitHub.com. You can also clone \`$MARKDOWN_REPOSITORY\` to your computer, check out the \`$branch_name\` branch, and edit *$markdown_file_path* in your text editor of choice.

$(cat $workflow_repository_clone_path/$PULL_BODY_TEMPLATE_FILE_PATH)
EOF

    # Prepare JSON payload for API request to create pull request.

    cat << EOF > $json_scratch_file_path
{
  "head": "$branch_name",
  "base": "$base_branch_name",
  "title": $(jq -Rs . <<< $pull_title),
  "body": $(jq -Rs . < $pull_body_scratch_file_path)
  $([ "$PULL_IS_DRAFT" == 'true' ] && echo ,\"draft\": \"true\")
}
EOF

    pulls_api_response=$(post_to_api $markdown_repository_api_url/pulls \
                         $json_scratch_file_path)

    pulls_api_response_code=$(parse_api_response_code "$pulls_api_response")

    # Parse response from API request to create pull request.

    case "$pulls_api_response_code" in

      # Success creating the pull request (📚 https://git.io/Jfh6s).

      201)
        pull_url=$(parse_api_response_body "$pulls_api_response" | jq -r .html_url)
        issue_comment_body="\`@$ACTOR\` applied the \`$LABEL\` label to this issue, so I created $pull_url 🤖"

        >&2 echo "ℹ️ Created $pull_url (HTTP $pulls_api_response_code)"

        exit_code=0
        step_status=done
        ;;

      # Any response other than success for creating the pull request.

      *)
        issue_comment_body="@$ACTOR applied the \`$LABEL\` label to this issue, but something went wrong when I tried to create a pull request with a Markdown file ❌ For more information, see [the workflow run details]($workflow_repository_url/actions/runs/$GITHUB_RUN_ID)."

        echo "::error ::Failed creating pull request in $MARKDOWN_REPOSITORY (HTTP $pulls_api_response_code)"
        >&2 echo "❌ $(parse_api_response_body "$pulls_api_response")"

        exit_code=1
        step_status=done
        ;;
    esac
  fi

  # ----------------------------------------------------------------- Finish up

  if [ "$step_status" == "done" ]; then
    if [[ $pushed_branch ]] && [[ "$pulls_api_response_code" -ne 201 ]]; then
      >&2 echo ℹ️ Deleting $branch_name on remote...

      git checkout $base_branch_name
      git push origin --delete $branch_name
    fi

    if [ "$COMMENT_ON_ISSUE" == 'true' ]; then

      # ---------------------------- Comment on issue that triggered workflow

      # Prepare the JSON payload for API request to create the issue comment.

      cat << EOF > $json_scratch_file_path
{
  "body": "$issue_comment_body"
}
EOF

      issues_api_response=$(post_to_api $ISSUE_COMMENTS_API_URL \
                            $json_scratch_file_path)

      issues_api_response_code=$(parse_api_response_code "$issues_api_response")

      case "$issues_api_response_code" in

        # Success creating the comment (📚 https://git.io/Jfh6t).

        201)
          >&2 echo "ℹ️ Commented on $ISSUE_URL (HTTP $issues_api_response_code)"
          ;;

        # Any response other than success for creating the comment.

        *)
          echo "::warning ::Failed commenting on $ISSUE_URL (HTTP $issues_api_response_code)"
          >&2 echo "⚠️ $(parse_api_response_body "$issues_api_response")"
          ;;
      esac
    fi
  fi
fi

exit $exit_code
