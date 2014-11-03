class smb (  )
inherits smb::params 
{
   notify { "This class requires a manual keytab to be created with {host,nfs,[cifs]}/$(hostname).physics.ox.ac.uk@PHYSICS.OX.AC.UK, " : }
   notify { "To do this: create a user in the Users part of the AD, name should be [svcname][hsotname] eg nfsCplxfs3.  Next log on to DC3, open an administrator command prompt, and run ktpass -princ [svc]/fqdn@PHYSICS.OX.AC.UK -mapuser {svcname}{hostname}@PHYSICS.OX.AC.UK -mapop add -out new.keytab.  Secure copy this from DC3 to /etc/krb5.keytab on the new file server" : }
#   class { "oxford_nfs_server::generic" : }
#   class { "oxford_nfs_server::nfs" : }
    class { "smb::generic" : }
#   class { "smb::server" : }
    class { "smb::client" : }
}

class smb::generic   (
   $secretsfilepath = $smb::params::secretsfilepath,
   $configfilepath = $smb::params::configfilepath,
   $smbserviceensure = $smb::params::smbserviceensure,
   $smbserviceenable = $smb::params::smbserviceenable
) inherits smb::params
{

   file { '/etc/request-key.conf':
         ensure =>present,
         source  => "puppet:///$secretsfilepath/request-key.conf",
         owner   => 'root',
         group   => 'root',
         mode    => '0444',
         notify =>  [Service['smb']],
  }
 
   $central_samba_packagelist = ['samba', 'openldap-clients']
   service{  ['nmb','smb'] :
                   ensure => $smbserviceensure,
                   hasstatus => true,
                   hasrestart => true,
                   enable => str2bool($smbserviceenable),
                   require => Package[$central_samba_packagelist]
    }
   file { '/etc/samba':
          ensure => directory,
          require => Package[$central_samba_packagelist],
   }
   ensure_packages ( $central_samba_packagelist )
   file { '/etc/samba/smb.conf' :
           source => "puppet:///$configfilepath",
           owner => 'root',
           group => 'root',
           mode => 0444,
           notify => Service['nmb','smb']
      }

}
class smb::server ( 
   $secretsfilepath = $smb::params::secretsfilepath,
   $configfilepath = $smb::params::configfilepath
) inherits smb::params
{

   $central_samba_packagelist = ['samba', 'openldap-clients']
   ensure_packages ( $central_samba_packagelist )

  file { '/etc/pam.d/samba' : 
           source  =>  "puppet:///$secretsfilepath/pam_samba", 
           owner => 'root',
           group => 'root',
           mode => 0444,
      }
   class { smb::generic : 
       smbserviceensure => "running",
       smbserviceenable => "true"
   }

}

class smb::client (
  $secretsfilepath = $smb::params::secretsfilepath,
  $configfilepath = $smb::params::configfilepath
) inherits smb::params
{
   class { smb::generic : 
       smbserviceensure => "stopped",
       smbserviceenable => "false"
   }
    
   service{  'nfsfilereader' :
                   ensure => "running",
                   hasstatus => true,
                   hasrestart => true,
                   enable => true,
                   subscribe => File['/etc/krb5.keytab.nfsreader']
    }
    file { '/etc/krb5.keytab.nfsreader' :
           source  =>  "puppet:///$secretsfilepath/krb5.keytab.nfsreader",
           owner => 'root',
           group => 'root',
           mode => 0600,
           notify => Service['nfsfilereader']
     }
    file { '/etc/init.d/nfsfilereader' :
           source  =>  "puppet:///modules/$module_name/nfsfilereader",
           owner => 'root',
           group => 'root',
           mode => 0755,
           notify => Service['nfsfilereader']
      }
    file { '/usr/bin/gen_dfs' :
           source  =>  "puppet:///modules/$module_name/gen_dfs",
           owner => 'root',
           group => 'root',
           mode => 0755,
           notify  => Exec[generate_dfs_emulator],
      }
    file { '/etc/auto.dfs.xml' :
           source  =>  "puppet:///site_files/generated_files/auto.dfs.xml",
           owner => 'root',
           group => 'root',
           mode => 0644,
           notify  => Exec[generate_dfs_emulator],
      }

  file { '/physics':
          ensure =>directory,
          notify => Service["autofs"],
  }
ensure_resource ( 'file', "/etc/automount",
  {
          ensure  => 'directory',
          mode    => '0755',
          owner   => 'root',
          group   => 'root',
  }
)

  file { "/etc/automount/auto.home.samba":
         ensure => present,
         mode => 0755,
         group => 'root',
         owner => 'root',
         source => "puppet:///modules/$module_name/auto.home.samba",
         require => File["/etc/automount"],

  }
  exec { 'generate_dfs_emulator':
        command => "/usr/bin/gen_dfs /etc/auto.dfs",
        refreshonly => true
    }

  $map = '/etc/auto.dfs'
  $options_keys =['--timeout', '-g' ]
  $options_values  =[ '-120','']
  $dir = '/-'

   case $::augeasversion {
       '0.9.0','0.10.0', '1.0.0': { $lenspath = '/var/lib/puppet/lib/augeas/lenses' }
        default: { $lenspath = undef }
     }

#######################################
 #Pattern based on
 #http://projects.puppetlabs.com/projects/1/wiki/puppet_augeas

     augeas{"${dir}_edit":

       context   => '/files/etc/auto.master/',

       load_path => $lenspath,
       #This part changes options on an already existing line

      changes   => [
             "set *[map = '$map']     $dir",
             "set *[map = '$map']/map  $map",
             "set *[map = '$map']/opt[1] ${options_keys[0]}",
             "set *[map = '$map']/opt[1]/value ${options_values[0]}",
             "set *[map = '$map']/opt[2] ${options_keys[1]}",
        ]   ,
       notify    => Service['autofs']
     }
     augeas{"${dir}_change":
       context   => '/files/etc/auto.master/',
       load_path => $lenspath,
       #This part changes options on an already existing line
       changes   => [
             "set 01   $dir",
             "set 01/map  $map",
             "set 01/opt[1] ${options_keys[0]}",
             "set 01/opt[1]/value ${options_values[0]}",
             "set 01/opt[2] ${options_keys[1]}",
        ]   ,
       onlyif    => "match *[map = '$map'] size == 0",

       notify    => Service['autofs']
     }
}
#######################################



