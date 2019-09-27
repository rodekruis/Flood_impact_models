from ftplib import FTP
import os


def downloadFiles(destination, cutoff_year=1999, file_pattern='tif.gz'):
  folderlist = ftp.nlst()
  main_dir = ftp.pwd()
  for folder in folderlist:
    if int(folder) >= cutoff_year:
      ftp.cwd('{}/{}'.format(main_dir, folder))
      filelist = ftp.nlst()
      for file in filelist:
          if file_pattern in file:
              ftp.retrbinary("RETR " + file, open(os.path.join(destination,file),"wb").write)
              print(file + " downloaded")
  return


ftp = FTP('ftp.chg.ucsb.edu')
ftp.login(user='', passwd = '')
ftp.cwd('/pub/org/chg/products/CHIRPS-2.0/africa_daily/tifs/p05/')
dest = os.path.join(os.getcwd(), '..', 'raw_data', 'chirps_full')
downloadFiles(dest)
ftp.quit()
