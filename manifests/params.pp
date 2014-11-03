class smb::params ( 
      $secretsfilepath = hiera("smb::params::secretsfilepath",  "modules/$module_name"), 
      $configfilepath =  hiera("smb::params::configfilepath", "modules/$module_name/smb.conf") ,
      $idmapdfilepath = hiera("smb::params::idmapdfilepath", "modules/$module_name"),
      $smbserviceensure  = hiera(smb::params::smbserviceensure,"stopped"),
      $smbserviceenable = hiera(smb::params::smbserviceenable,"false"),
)
{ 
   notify { "This class requires a manual keytab to be created with {host/$(hostname).physics.ox.ac.uk@PHYSICS.OX.AC.UK.. ": }

}
