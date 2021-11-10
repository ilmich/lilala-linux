# put libc in the right place
( cd lib/incoming ; mv libc.so ../ )
# cleanup
rm -rf lib/incoming

