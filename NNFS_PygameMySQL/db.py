import mysql.connector
from mysql.connector import errorcode
from mysql.connector import Error

def disp():
    try:
       mySQLconnection = mysql.connector.connect(host='localhost',
                                 database='gameboard',
                                 user='root',
                                 password='')

       sql_select_Query = "SELECT * FROM user_info ORDER BY score DESC"
       cursor = mySQLconnection.cursor()
       cursor.execute(sql_select_Query)
       records = cursor.fetchall()

       print("Total number of rows in student is - ", cursor.rowcount)
       print ("Printing each row's column values i.e.  student record")
      # for row in records:
      #     print("SId = ", row[0], )
      #     print("SName = ", row[1])
      #     print("AGE  = ", row[2])
      #     print("BRANCH  = ", row[3])
      #     print("EMAIL  = ", row[4])
      #     print("MOB_No  = ", row[5], "\n")

       for row in records:
           print(row[0],"\t",row[1],"\t""\n")

       cursor.close()
       
    except Error as e :
        print ("Error while connecting to MySQL", e)
    finally:
        #closing database connection.
        if(mySQLconnection.is_connected()):
            mySQLconnection.close()
            print("MySQL connection is closed")

def insert(name,score):
    global x
    try:
       connection = mysql.connector.connect(host='localhost',
                                 database='gameboard',
                                 user='root',
                                 password='')

       #x=str(input("Enter you name"))
       #y=input("Enter your score")
       sql_insert_query = ("INSERT INTO user_info(name, score) VALUES (%s,%s)", (name, score))

       cursor = connection.cursor()
       result  = cursor.execute(*sql_insert_query)
       connection.commit()
       print ("Record inserted successfully into python_users table")

    except mysql.connector.Error as error :
        connection.rollback() #rollback if any exception occured
        print("Failed inserting record into python_users table {}".format(error))

    finally:
        #closing database connection.
        if(connection.is_connected()):
            cursor.close()
            connection.close()
            print("MySQL connection is closed")
            

            
def update(name,score):
    try:
       conn = mysql.connector.connect(host='localhost',
                                 database='gameboard',
                                 user='root',
                                 password='')
       cursor = conn.cursor()

       print ("Before updating record ")
       sql_select_query = """select * from user_info where score = 999"""
       cursor.execute(sql_select_query)
       record = cursor.fetchone()
       print (record)

       #Update single record now
       sql_update_query = """Update user_info set name = 'Kevin' where score = 9999"""
       cursor.execute(sql_update_query)
       #connection.commit()
       print ("Record Updated successfully ")

       print("After updating record ")
       cursor.execute(sql_select_query)
       record = cursor.fetchone()
       print(record)

    except mysql.connector.Error as error :
        print("Failed to update record to database: {}".format(error))
        connection.rollback()

    finally:
        #closing database connection.
        if(conn.is_connected()):
            conn.close()
            print("connection is closed")
            

disp()
