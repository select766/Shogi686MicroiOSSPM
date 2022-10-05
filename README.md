# shogi686micro iOS移植サンプル(Swift Package Manager使用)

将棋の思考エンジンをパッケージ化した https://github.com/select766/Shogi686MicroSPM をiOSアプリの形にラップするサンプル。
まだ動かない。

# ビルド
Xcodeでビルドが必要。

Package Dependenciesに`Shogi686MicroSPM`がある。ローカルファイルの絶対パスを指定しているので改善する必要がある。
`Shogi686MicroSPM`の内容を更新した場合、`Shogi686MicroSPM`を右クリックしてUpdate Packageをクリックする。
