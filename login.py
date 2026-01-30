def login(username, password):
    if username == "admin" and password == "password123":
        return True
    return False

def validate_username(username):
    return len(username) > 3
