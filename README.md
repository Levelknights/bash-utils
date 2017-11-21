## bash-utils 

## Notes

* Rename tags (also on origin):
Example: Rename all "release-*" tags replacing dash to slash: '-' >> '/'. (release-1.0 to release/1.0)
```bash
for i in $(git tag | grep 'release-'); do nr=$(echo $i | tr '-' '/'); git tag $nr $i; git tag -d $i; git push origin :$i ;  done ; git push origin --tags
```
