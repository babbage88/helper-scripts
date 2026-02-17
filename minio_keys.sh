create-miniokey() {
  MUSER=${1-"devuser"}
  mc admin user svcacct add m1 $MUSER
}
