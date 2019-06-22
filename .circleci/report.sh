#!/bin/bash

function transform_checkstyle() {
  target=build/reports/checkstyle/main.xml
  if [[ ! -e $target ]]; then
    return
  fi

  filecount=1
  while :
  do
    filename_xml=$(echo "cat /checkstyle/file[$filecount]/@name" | xmllint --shell $target)
    if [ "${filename_xml}" = "/ > / > " ]; then
      break
    fi
    filename=$(echo ${filename_xml} | sed -e "s/^.*name=\"\(.*\)\".*$/\1/" | sed -e "s/^.*\(src\/.*\)$/\1/")

    errorcount=1
    while :
    do
      error_xml=$(echo "cat /checkstyle/file[$filecount]/error[$errorcount]" | xmllint --shell $target)
      if [ "${error_xml}" = "/ > / > " ]; then
        break
      fi
      line=$(echo ${error_xml} | sed -e "s/^.*line=\"\([^\"]*\)\".*$/\1/")
      column=$(echo ${error_xml} | sed -e "s/^.*column=\"\([^\"]*\)\".*$/\1/")
      severity=$(echo ${error_xml} | sed -e "s/^.*severity=\"\([^\"]*\)\".*$/\1/")
      message=$(echo ${error_xml} | sed -e "s/^.*message=\"\([^\"]*\)\".*$/\1/")

      echo "${filename}:$line \(${severity}\)checkstyle $message"
      errorcount=$((errorcount + 1))
    done
    filecount=$((filecount + 1))
  done
}

function transform_pmd() {
  target=build/reports/pmd/main.xml
  if [[ ! -e $target ]]; then
    return
  fi

  filecount=1
  while :
  do
    filename_xml=$(echo "cat /*[local-name()='pmd']/*[local-name()='file'][$filecount]/@name" | xmllint --shell $target)
    if [ "${filename_xml}" = "/ > / > " ]; then
      break
    fi
    filename=$(echo ${filename_xml} | sed -e "s/^.*name=\"\(.*\)\".*$/\1/" | sed -e "s/^.*\(src\/.*\)$/\1/")

    errorcount=1
    while :
    do
      error_xml=$(echo "cat /*[local-name()='pmd']/*[local-name()='file'][$filecount]/*[local-name()='violation'][$errorcount]" | xmllint --shell $target)
      if [ "${error_xml}" = "/ > / > " ]; then
        break
      fi
      line=$(echo ${error_xml} | sed -e "s/^.*beginline=\"\([^\"]*\)\".*$/\1/")
      column=$(echo ${error_xml} | sed -e "s/^.*begincolumn=\"\([^\"]*\)\".*$/\1/")
      severity=$(echo ${error_xml} | sed -e "s/^.*priority=\"\([^\"]*\)\".*$/\1/")
      ruleset=$(echo ${error_xml} | sed -e "s/^.*ruleset=\"\([^\"]*\)\".*$/\1/")
      rule=$(echo ${error_xml} | sed -e "s/^.*rule=\"\([^\"]*\)\".*$/\1/")
      message=$(echo ${ruleset}: $rule)

      echo "${filename}:$line \(${severity}\)pmd $message"
      errorcount=$((errorcount + 1))
    done
    filecount=$((filecount + 1))
  done
}

function transform_spotbugs() {
  target=build/reports/spotbugs/main.xml
  if [[ ! -e $target ]]; then
    return
  fi

  errorcount=1
  while :
  do
    error_xml=$(echo "cat /BugCollection/BugInstance[$errorcount]" | xmllint --shell $target)
    if [ "${error_xml}" = "/ > / > " ]; then
      break
    fi
    severity=$(echo ${error_xml} | sed -e "s/^.*priority=\"\([^\"]*\)\".*$/\1/")
    category=$(echo ${error_xml} | sed -e "s/^.*category=\"\([^\"]*\)\".*$/\1/")
    type=$(echo ${error_xml} | sed -e "s/^.*type=\"\([^\"]*\)\".*$/\1/")
    message=$(echo ${category}: $type)

    sourcecount=1
    while :
    do
      source_xml=$(echo "cat /BugCollection/BugInstance[$errorcount]/Class/SourceLine[$sourcecount]" | xmllint --shell $target)
      if [ "${source_xml}" = "/ > / > " ]; then
        break
      fi
      filename=$(echo ${source_xml} | sed -e "s/^.*sourcepath=\"\(.*\)\".*$/\1/")
      line=$(echo ${source_xml} | sed -e "s/^.*start=\"\([^\"]*\)\".*$/\1/")

      echo "src/main/java/"${filename}:$line \(${severity}\)spotbugs $message
      sourcecount=$((sourcecount + 1))
    done
    errorcount=$((errorcount + 1))
  done
}

function difflint() {
  BASE_REMOTE=origin
  BASE_BRANCH=master
  git fetch $BASE_REMOTE $BASE_BRANCH > /dev/null 2>&1
  git branch | grep master > /dev/null || git branch $BASE_BRANCH $BASE_REMOTE/$BASE_BRANCH

  diff_list=()
  commit_list=`git --no-pager log --no-merges $BASE_REMOTE/$BASE_BRANCH...HEAD | grep -e '^commit' | sed -e "s/^commit \(.\{8\}\).*/\1/"`
  for f in `git --no-pager diff $BASE_REMOTE/$BASE_BRANCH...HEAD --name-only`; do
    if [ -e $f ]; then
      for c in $commit_list; do
        diffs=`git --no-pager blame --show-name -s $f | grep $c | sed -e "s/^[^ ]* *\([^ ]*\) *\([0-9]*\)*).*$/\1:\2/"`
        for ln in $diffs; do
          diff_list+=( $ln )
        done
      done
    fi
  done

  cat build/tmp/errors/* | sort | while read ln; do
    for m in ${diff_list[@]}; do
      if [[ ${ln} =~ ^$m ]]; then
        echo $ln
        err_count=$((err_count+1))
        break
      fi
    done
  done
}

mkdir -p build/tmp/errors
transform_checkstyle > build/tmp/errors/checkstyle.txt
transform_pmd > build/tmp/errors/pmd.txt
transform_spotbugs > build/tmp/errors/spotbugs.txt
ERRORS=$(difflint)
echo "$ERRORS"

GITHUB_API_URL=https://api.github.com
CIRCLE_PR_NUMBER="${CIRCLE_PR_NUMBER:-${CIRCLE_PULL_REQUEST##*/}}"

if [ "$CIRCLE_PR_NUMBER" != "" ]; then
  GH_COMMENT_OWNER=$(echo $GITHUB_ACCESS_TOKEN | sed 's/^\(.*\):.*$/\1/')

  # 既存コメントのクリア
  REQUEST_URL=$GITHUB_API_URL/repos/$CIRCLE_PROJECT_USERNAME/$CIRCLE_PROJECT_REPONAME/issues/$CIRCLE_PR_NUMBER/comments
  JQ_FILTER=".[] | select( .user.login == \"$GH_COMMENT_OWNER\")"
  COMMENTS=$(curl -u $GITHUB_ACCESS_TOKEN $REQUEST_URL | jq "$JQ_FILTER" | jq -r '.id')
  for c in $COMMENTS; do
    curl -s -u $GITHUB_ACCESS_TOKEN \
         -X DELETE \
         $GITHUB_API_URL/repos/$CIRCLE_PROJECT_USERNAME/$CIRCLE_PROJECT_REPONAME/issues/comments/$c
  done

  # コメント用エラーメッセージの生成
  ERROR_MESSAGES=$(echo "$ERRORS" | while read ln; do
    FILENAME=$(echo $ln | sed 's/^\([^:]*\):[0-9]* .*$/\1/')
    FILELINE=$(echo $ln | sed 's/^[^:]*:\([0-9]*\) .*$/\1/')
    MESSAGE=$(echo $ln | sed 's/^[^:]*:[0-9]* \(.*\)$/\1/')
    echo "[$FILENAME:$FILELINE](https://github.com/$CIRCLE_PROJECT_USERNAME/$CIRCLE_PROJECT_REPONAME/blob/$CIRCLE_BRANCH/${FILENAME}#L${FILELINE}) $MESSAGE"
  done | sed "s/^/- /")

  # レポートバッジの生成
  URL_LIST=$(curl https://circleci.com/api/v1.1/project/github/$CIRCLE_PROJECT_USERNAME/$CIRCLE_PROJECT_REPONAME/$CIRCLE_BUILD_NUM/artifacts?circle-token=$CIRCLE_TOKEN | jq -r '.[].url')
  URL_PMD=$(echo "$URL_LIST" | grep "pmd/main.html$")
  URL_CHECKSTYLE=$(echo "$URL_LIST" | grep "checkstyle/main.html$")
  REPORT_BADGES="[![checkstyle](https://img.shields.io/badge/report-checkstyle-yellow.svg)]($URL_CHECKSTYLE) [![pmd](https://img.shields.io/badge/report-pmd-red.svg)]($URL_PMD)"

  # コメントの投稿
  TEMPLATE=$(cat .circleci/comment.txt)
  MESSAGE_BODY=$(eval "echo \"$TEMPLATE\"")
  GH_COMMENT_BODY=$(echo "$MESSAGE_BODY" | sed "s/$/\<br\>/" | tr '\n' ' ')
  curl -s -u $GITHUB_ACCESS_TOKEN \
       -X POST \
      --data "{\"body\":\"$GH_COMMENT_BODY\"}" \
      $GITHUB_API_URL/repos/$CIRCLE_PROJECT_USERNAME/$CIRCLE_PROJECT_REPONAME/issues/$CIRCLE_PR_NUMBER/comments

fi