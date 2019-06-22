# circlecijp-20190628

このリポジトリは、  
2017/06/28開催の「CircleCI ユーザーコミュニティミートアップ #5」での発表  
「CircleCIを使ったSpringBoot/GAEアプリ開発の効率化ノウハウ」の参考ソースコードです。

CircleCI ユーザーコミュニティミートアップ #5  
2019.06.28 @ ビズリーチ  
https://circleci.connpass.com/event/134440/


## ローカル環境での実行

1. Java8をインスト−ル

   https://www.oracle.com/technetwork/java/javase/downloads/java-archive-javase8-2177648.html

2. Gradleをインストール

   https://gradle.org/

3. Google Cloud SDKをインストール。

   https://cloud.google.com/sdk/downloads?hl=ja

4. Cloud SDKの初期化

   ```
   gcloud init
   ```

   既に初期化済みであれば、ログインとプロジェクトの設定をしておく。

   ```
   gcloud auth login
   gcloud config set project (プロジェクト名)
   ```

5. Cloud SDKの関連コンポーネントをインストール

   ```
   gcloud components install app-engine-java
   gcloud components install gsutil
   ```

6. 開発環境を実行

   ```
   gradle appengineRun
   ```


## CircleCIでの実行

1. CircleCIで、対象リポジトリのビルドを有効化

2. 以下の環境変数を設定する

   - CIRCLE_TOKEN	... CircleCIのAPI token
   - GITHUB_ACCESS_TOKEN ... GitHubのbotユーザのAccessToken
   - GCLOUD_SERVICE_KEY	... GCPのサービスアカウントのキー(JSON)
   - GOOGLE_PROJECT_ID ... GCPのプロジェクト名

3. 修正を加えて、PullRequestを作る
