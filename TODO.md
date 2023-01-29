# TODO

Voir si on peut pas facto ce bout de code (je pense vu que les var SERVERS et SERVER sont définis globalement):

```bash
for KEY in "${!SERVERS[@]}"; do
    eval "${SERVERS["$KEY"]}"
    if [[ ${SERVER[NAME]} == $server_name ]]; then
        break
    fi
done
```
