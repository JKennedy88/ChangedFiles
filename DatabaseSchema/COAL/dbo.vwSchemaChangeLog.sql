create view vwSchemaChangeLog AS

select 
	isnull(h.dteDeploymentDate,s.createDate) as DeployDate,
	isnull(h.vchDeployerName,s.LoginName) as DeployName,
	h.vchReleaseNumber as ReleaseNumber,
	h.vchNotes as ReleaseNotes,
	s.DBName, 
	s.SQLEvent, 
	s.[Schema],
	s.ObjectName,
	s.SQLCmd
from 
	SchemaChangeLog as s with (nolock)

left join Audit..dtlDeploymentLog_Detail as d with (nolock)
	on s.SchemaChangeLogID = d.intSchemaChangeLogID
	and s.DBName = d.vchDatabaseName

left join Audit..dtlDeploymentLog_Header as h with (nolock) 
	on h.intDeployID = d.intDeployID

