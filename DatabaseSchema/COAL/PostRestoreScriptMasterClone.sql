--Drop Orphan Users

if @@servername not like '%server%'
	begin


		create table #orphanedUsers (
			[Database] varchar(250),
			[OrphanedUser] varchar(250)
		)


		exec sp_msforeachdb '

		insert into #orphanedUsers ([Database], [OrphanedUser])
		select  
			''?'' as [Database], 
			su.Name as [OrphanedUser]	
		from [?]..sysusers su
		where
			su.islogin = 1
			and su.name not in (''guest'',''sys'',''INFORMATION_SCHEMA'',''dbo'', ''MS_DataCollectorInternalUser'')
			and not exists (
				select 
					*
				from master..syslogins as sl
				where su.[sid] = sl.[sid]
			)

		'


		select 
			[Database], 
			[OrphanedUser],
			'use [' + [Database] + '] drop user [' + [OrphanedUser] + ']'  as userDropScript
		into #dropScript
		from #orphanedUsers
		order by
			[Database], 
			[OrphanedUser]

	declare @dropScript varchar(255)

	while exists(select top 1 * from #dropScript)
		begin 
			select top 1 @dropScript = userDropScript
			from #dropScript

			exec(@dropScript)

			delete from #dropScript
			where userDropScript = @dropScript

		end

	drop table #orphanedUsers,#dropScript

	end

go



--Create new databases

use [master]
		
		 --create AD logins
		declare @sql varchar(max)

		if not exists (select * from sys.server_principals where name = 'GPP\SQL.Admin')
		begin
			create login [GPP\SQL.Admin] from windows with default_database=[master], default_language=[us_english]
		end

		if not exists (select * from sys.server_principals where name = 'GPP\sql.engine')
		begin
			create login [GPP\sql.engine] from windows with default_database=[master], default_language=[us_english]
		end

		if not exists (select * from sys.server_principals where name = 'GPP\sql.reporting')
		begin
			create login [GPP\sql.reporting] from windows with default_database=[master], default_language=[us_english]
		end

		if not exists (select * from sys.server_principals where name = 'GPP\sql.agent')
		begin
			create login [GPP\sql.agent] from windows with default_database=[master], default_language=[us_english]
		end

		if not exists (select name from sys.server_principals where cast(name as varchar(250)) = 'GPP\SQL.' + cast(serverproperty('ServerName') as varchar(250)) + '.ReadWriteExecAlter')
		begin	
			set @sql = N'create login [GPP\SQL.' + cast(serverproperty('ServerName') as nvarchar(250)) + N'.ReadWriteExecAlter] from windows with default_database=[master], default_language=[us_english]'
			exec (@sql)
		end

		if not exists (select name from sys.server_principals where cast(name as varchar(250)) = 'GPP\SQL.' + cast(serverproperty('ServerName') as varchar(250)) + '.ReadWriteExec')
		begin	
			set @sql = N'create login [GPP\SQL.' + cast(serverproperty('ServerName') as nvarchar(250)) + N'.ReadWriteExec] from windows with default_database=[master], default_language=[us_english]'
			exec (@sql)
		end

		if not exists (select name from sys.server_principals where cast(name as varchar(250)) = 'GPP\SQL.' + cast(serverproperty('ServerName') as varchar(250)) + '.ReadOnly')
		begin	
			set @sql = N'create login [GPP\SQL.' + cast(serverproperty('ServerName') as nvarchar(250)) + N'.ReadOnly] from windows with default_database=[master], default_language=[us_english]'
			exec (@sql)
		end

		


		--create server roles
		if not exists (select * from sys.server_principals where name = 'sysuser')
		begin
			create server role [sysuser] authorization [sa]
		end
		

		--assign rights
		grant alter any connection to [sysuser]
		grant connect any database to [sysuser]
		grant view any definition to [sysuser]
		grant view server state to [sysuser]
		deny alter trace to [sysuser]
		

		set @sql =null 

		if exists (select * from sys.server_principals where name = 'GPP\SQL.Admin')
		begin
			alter server role [sysadmin] add member [GPP\SQL.Admin]
		end

		if exists (select * from sys.server_principals where name = 'GPP\sql.engine')
		begin
			alter server role [sysadmin] add member [GPP\sql.engine]
		end

		if exists (select * from sys.server_principals where name = 'GPP\sql.reporting')
		begin
			alter server role [sysadmin] add member [GPP\sql.reporting]
		end

		if exists (select * from sys.server_principals where name = 'GPP\sql.agent')
		begin
			alter server role [sysadmin] add member [GPP\sql.agent]
		end



		if exists (select name from sys.server_principals where cast(name as varchar(250)) = 'GPP\SQL.' + cast(serverproperty('ServerName') as varchar(250)) + '.ReadWriteExecAlter')
		begin
			set @sql = N'alter server role [sysuser] add member [GPP\SQL.' + cast(serverproperty('ServerName') as nvarchar(250)) + N'.ReadWriteExecAlter]'
			exec (@sql)

			if exists (select name from sys.server_principals where name = 'GBOBespokeApplicationElevated')
			begin
				set @sql = N'grant impersonate on login::[GBOBespokeApplicationElevated] to [GPP\SQL.' + cast(serverproperty('ServerName') as nvarchar(250)) + N'.ReadWriteExecAlter]'
				exec (@sql)
			end
		end

		if exists (select name from sys.server_principals where cast(name as varchar(250)) = 'GPP\SQL.' + cast(serverproperty('ServerName') as varchar(250)) + '.ReadWriteExec')
		begin
			set @sql = N'alter server role [sysuser] add member [GPP\SQL.' + cast(serverproperty('ServerName') as nvarchar(250)) + N'.ReadWriteExec]'
			exec (@sql)

			if exists (select name from sys.server_principals where name = 'GBOBespokeApplicationElevated')
			begin
				set @sql = N'grant impersonate on login::[GBOBespokeApplicationElevated] to [GPP\SQL.' + cast(serverproperty('ServerName') as nvarchar(250)) + N'.ReadWriteExec]'
				exec (@sql)
			end
		end

		if exists (select name from sys.server_principals where cast(name as varchar(250)) = 'GPP\SQL.' + cast(serverproperty('ServerName') as varchar(250)) + '.ReadOnly')
		begin
			set @sql = N'alter server role [sysuser] add member [GPP\SQL.' + cast(serverproperty('ServerName') as nvarchar(250)) + N'.ReadOnly]'
			exec (@sql)
		end
		


		if object_id('tempdb..#db') is not null
		begin
			drop table #db
		end


		create table #db (
			db varchar(250)
		)

		insert into #db (db)
		select 
			name as db 
		from sys.databases 
		where state_desc = 'online'

		set @sql = null

		declare 
			@db nvarchar(250)

		while exists (select * from #db)
		begin
			select
				@db = db
			from #db

			print @db

			select @sql = '
					use [' + @db + ']
					
					if database_principal_id(''db_user'') is null
					begin
						create role db_user				
					end

					if database_principal_id(''db_execute'') is null
					begin				
						create role db_execute
					end
					
					grant execute to [db_execute]
					grant showplan to [db_user]
								
					if exists (select * from sys.tables where name = ''SchemaChangeLog'')
					begin
						deny alter on SchemaChangeLog to [db_user]
						deny delete on SchemaChangeLog to [db_user]
						deny update on SchemaChangeLog to [db_user]
						deny alter any database ddl trigger to [db_user]				
					end

					if ''' + @db + ''' = ''CentralTransactionalStore''
					begin
						if exists (select * from sys.tables where name = ''dtlTransactions'')
						begin
							grant alter on [dtlTransactions] to [db_execute]
						end
						
						if exists (select * from sys.tables where name = ''dtlTransactionMovements'')
						begin
							grant alter on [dtlTransactionMovements] to [db_execute]
						end				
						
						if exists (select * from sys.tables where name = ''dtlSecurityBook'')
						begin
							grant alter on [dtlSecurityBook] to [db_execute]
						end				
						
						if exists (select * from sys.tables where name = ''dtlCommissionBook'')
						begin
							grant alter on [dtlCommissionBook] to [db_execute]
						end				
						
						if exists (select * from sys.tables where name = ''dtlCashBook'')
						begin
							grant alter on [dtlCashBook] to [db_execute]
						end				
						
						if exists (select * from sys.tables where name = ''dtlCashDepositWithdrawalBook'')
					begin
						grant alter on [dtlCashDepositWithdrawalBook] to [db_execute]
					end				
					
					if exists (select * from sys.tables where name = ''dtlFeeBook'')
					begin
						grant alter on [dtlFeeBook] to [db_execute]
					end				
					
					if exists (select * from sys.tables where name = ''dtlFXBook'')
					begin
						grant alter on [dtlFXBook] to [db_execute]
					end				
					
					if exists (select * from sys.tables where name = ''dtlInternalInterestBook'')
					begin
						grant alter on [dtlInternalInterestBook] to [db_execute]
					end				
					
					if exists (select * from sys.tables where name = ''dtlSecuritiesLendingBook'')
					begin
						grant alter on [dtlSecuritiesLendingBook] to [db_execute]
					end				
					
					if exists (select * from sys.tables where name = ''dtlCashCollateralBook'')
					begin
						grant alter on [dtlCashCollateralBook] to [db_execute]
					end				
					
					if exists (select * from sys.tables where name = ''dtlSpreadIncomeBook'')
					begin
						grant alter on [dtlSpreadIncomeBook] to [db_execute]
					end				
					
					if exists (select * from sys.tables where name = ''dtlDividendBook'')
					begin
						grant alter on [dtlDividendBook] to [db_execute]
					end			
					
				end

			'
		--print (@sql)
		exec (@sql)



		select @sql = '
				use [' + @db + ']
			

				if not exists (select * from [' + @db + '].sys.database_principals where name = ''GPP\SQL.' + cast(serverproperty('ServerName') as nvarchar(250)) + N'.ReadWriteExecAlter'')
				begin
					create user [GPP\SQL.' + cast(serverproperty('ServerName') as nvarchar(250)) + N'.ReadWriteExecAlter] for login [GPP\SQL.' + cast(serverproperty('ServerName') as nvarchar(250)) + N'.ReadWriteExecAlter]
				end

				if not exists (select * from [' + @db + '].sys.database_principals where name = ''GPP\SQL.' + cast(serverproperty('ServerName') as nvarchar(250)) + N'.ReadWriteExec'')
				begin
					create user [GPP\SQL.' + cast(serverproperty('ServerName') as nvarchar(250)) + N'.ReadWriteExec] for login [GPP\SQL.' + cast(serverproperty('ServerName') as nvarchar(250)) + N'.ReadWriteExec]
				end

				if not exists (select * from [' + @db + '].sys.database_principals where name = ''GPP\SQL.' + cast(serverproperty('ServerName') as nvarchar(250)) + N'.ReadOnly'')
				begin
					create user [GPP\SQL.' + cast(serverproperty('ServerName') as nvarchar(250)) + N'.ReadOnly] for login [GPP\SQL.' + cast(serverproperty('ServerName') as nvarchar(250)) + N'.ReadOnly]
				end


				alter role [db_user] add member [GPP\SQL.' + cast(serverproperty('ServerName') as nvarchar(250)) + N'.ReadWriteExecAlter]
				alter role [db_user] add member [GPP\SQL.' + cast(serverproperty('ServerName') as nvarchar(250)) + N'.ReadWriteExec]
				alter role [db_user] add member [GPP\SQL.' + cast(serverproperty('ServerName') as nvarchar(250)) + N'.ReadOnly]

				alter role [db_datareader] add member [GPP\SQL.' + cast(serverproperty('ServerName') as nvarchar(250)) + N'.ReadWriteExecAlter]
				alter role [db_datareader] add member [GPP\SQL.' + cast(serverproperty('ServerName') as nvarchar(250)) + N'.ReadWriteExec]
				alter role [db_datareader] add member [GPP\SQL.' + cast(serverproperty('ServerName') as nvarchar(250)) + N'.ReadOnly]

				alter role [db_datawriter] add member [GPP\SQL.' + cast(serverproperty('ServerName') as nvarchar(250)) + N'.ReadWriteExecAlter]
				alter role [db_datawriter] add member [GPP\SQL.' + cast(serverproperty('ServerName') as nvarchar(250)) + N'.ReadWriteExec]

				alter role [db_execute] add member [GPP\SQL.' + cast(serverproperty('ServerName') as nvarchar(250)) + N'.ReadWriteExecAlter]
				alter role [db_execute] add member [GPP\SQL.' + cast(serverproperty('ServerName') as nvarchar(250)) + N'.ReadWriteExec]
				
				alter role [db_ddladmin] add member [GPP\SQL.' + cast(serverproperty('ServerName') as nvarchar(250)) + N'.ReadWriteExecAlter]


				if ''' + @db + ''' = ''msdb''
				begin
					alter role [SQLAgentOperatorRole] add member [GPP\SQL.' + cast(serverproperty('ServerName') as nvarchar(250)) + N'.ReadWriteExecAlter]
					alter role [SQLAgentUserRole] add member [GPP\SQL.' + cast(serverproperty('ServerName') as nvarchar(250)) + N'.ReadWriteExec]
					alter role [SQLAgentReaderRole] add member [GPP\SQL.' + cast(serverproperty('ServerName') as nvarchar(250)) + N'.ReadOnly]
				end

			'
		
		--print (@sql)
		exec (@sql)


			delete from #db
			where db = @db
		end

		drop table #db
		go

		use [master]
		go


		print 'Done'

go

USE [msdb]
GO
/***** Object:  DatabaseRole [db_gbobespokeappelevated]    Script Date: 7/20/2018 5:34:19 PM *****/
CREATE ROLE [db_gbobespokeappelevated]
GO
USE [master]
GO

if not exists(select name from sys.server_principals where name = 'GBOBespokeApplicationElevated')
CREATE LOGIN [GBOBespokeApplicationElevated] WITH PASSWORD=N'N+p6CMPzSHH5eMHUrFIeDE+eqsqZIC0LM/Js3jR9oro=', DEFAULT_DATABASE=[master], DEFAULT_LANGUAGE=[us_english], CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF
GO



EXEC sp_MSforeachdb
'USE [?]
CREATE ROLE [db_gbobespokeappelevated] AUTHORIZATION [dbo]
exec sp_addrolemember ''db_gbobespokeappelevated''  ,  ''db_user''  
'

GO
ALTER SERVER ROLE [sysuser] ADD MEMBER [GBOBespokeApplicationElevated]

USE [msdb]
GO
/***** Object:  DatabaseRole [db_gbobespokeappelevated]    Script Date: 7/20/2018 5:34:19 PM *****/
CREATE ROLE [db_gbobespokeappelevated]
GO
USE [master]
GO

if not exists(select name from sys.server_principals where name = 'GBOBespokeApplicationElevated')
CREATE LOGIN [GBOBespokeApplicationElevated] WITH PASSWORD=N'N+p6CMPzSHH5eMHUrFIeDE+eqsqZIC0LM/Js3jR9oro=', DEFAULT_DATABASE=[master], DEFAULT_LANGUAGE=[us_english], CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF
GO



EXEC sp_MSforeachdb
'USE [?]
CREATE ROLE [db_gbobespokeappelevated] AUTHORIZATION [dbo]
exec sp_addrolemember ''db_gbobespokeappelevated''  ,  ''db_user''  
'

GO

ALTER SERVER ROLE [sysuser] ADD MEMBER [GBOBespokeApplicationElevated]

exec sp_MSforeachdb
'use [?]
CREATE USER [GBOBespokeApplicationElevated] FOR LOGIN [GBOBespokeApplicationElevated]

ALTER ROLE [db_gbobespokeappelevated] ADD MEMBER [GBOBespokeApplicationElevated]
'

exec sp_msforeachdb '
use [?]
ALTER ROLE [db_datareader] ADD MEMBER [GBOBespokeApplicationElevated]
ALTER ROLE [db_datawriter] ADD MEMBER [GBOBespokeApplicationElevated]
ALTER ROLE [db_ddladmin] ADD MEMBER [GBOBespokeApplicationElevated]
ALTER ROLE [db_execute] ADD MEMBER [GBOBespokeApplicationElevated]
ALTER ROLE [db_user] ADD MEMBER [GBOBespokeApplicationElevated]'