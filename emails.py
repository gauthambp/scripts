emails = {}

try:
    email_file = open('emails2.txt' , 'r')

    for line in email_file:
        (email, name) = line.split(',')
        emails[email] = name.strip()




except FileNotFoundError as err:
    print(err)


print(emails)



try:
    schedule_fail = open('schedule.txt' , 'r')

    for line in schedule_fail:
        (schedule, time) = line.split(',')
        schedule_fail[sche]