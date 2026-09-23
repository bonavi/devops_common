ENV ?= prod

restore-db:
	./restorePgsqlDumpInK8S/restore-backups.sh $(ENV)

change-a-record:
	cd changeARecordInDigitalOcean && go run changeARecord.go
