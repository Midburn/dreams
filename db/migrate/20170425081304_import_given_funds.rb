class ImportGivenFunds < ActiveRecord::Migration
  def up
    a = ['120\t101', '167\t119', '131\t239', '80\t286', '161\t334', '115\t358', '121\t394', '60\t403', '118\t537',
         '123\t537', '116\t573', '188\t597', '154\t597', '68\t597', '141\t609', '42\t716', '95\t716', '85\t835',
         '130\t895', '88\t1074', '185\t1193', '52\t1193', '54\t1193', '89\t1312', '169\t1432', '51\t1485', '186\t1491',
         '83\t597', '180\t1790', '56\t1790', '184\t1790', '173\t1790', '63\t1790', '143\t1790', '53\t1915', '144\t1979',
         '137\t2077', '149\t2148', '142\t2237', '174\t2386', '79\t2397', '119\t2714', '57\t2926', '170\t1360',
         '177\t3430', '59\t3579', '50\t3624', '66\t4057', '125\t4773', '126\t4805', '87\t4875', '107\t5208',
         '106\t5966', '181\t5966', '75\t5966', '148\t7851', '77\t8352', '111\t8352', '112\t8412', '171\t8949',
         '113\t10738', '108\t11812', '55\t11982', '178\t14318', '122\t17897', '71\t20624', '172\t23863', '102\t20284',
         '70\t30426', '146\t917', '192\t850']
    a.each { |e|
      camp_id, money = e.split('\t').map(&:to_i)
      Camp.where(id: camp_id).update_all(given_funds: money)
    }
  end

  def down
    Camp.update_all(given_funds: nil)
  end
end
