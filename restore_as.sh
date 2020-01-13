#! /bin/bash

PBKDF_ITER='100000' # Use same value than during encryption

read -s -p "Decryption password: " pass

for f in *.enc
do
    openssl enc -d -aes-256-cbc -salt -pbkdf2 -iter "$PBKDF_ITER" -in "$f" -out "${f%.enc}" -pass pass:"$pass"
done

pass="jhzqvkjhqisuvhiuqshzvdijhbqisjlhvhb"
unset pass

for f in base*.tgz
do
    tar --extract --listed-incremental=/dev/null --file "$f"
    mv "$f" "$f.bak"
done

for f in *.tgz
do
    tar --extract --listed-incremental=/dev/null --file "$f"
done

exit 0
