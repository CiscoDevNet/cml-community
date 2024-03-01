import yaml
import os
import winreg
    
def generate_session_ini(label, port, lab_title, filename, parent_folder):
  """
  Generates a SecureCRT session.ini file with the provided information.

  Args:
    label (str): Label of the node.
    port (int): Listen port of the device.
    lab_title (str): Title of the lab.
    filename (str): Name of the session.ini file to create.
    parent_folder (str): Path to the parent folder where labs will be created.
  """
  # Ensure parent folder exists
  if not os.path.exists(parent_folder):
    os.makedirs(parent_folder)

# Create lab-specific folder within the parent folder
  lab_folder = parent_folder +"/" + lab_title
  if not os.path.exists(lab_folder):
    os.makedirs(lab_folder)
  

  hexport = hex(port).split('x')[-1]
                                 
  filepath = lab_folder + "/" + filename
  with open(filepath, "w") as file:
    file.write(f"S:\"Hostname\"=::1\n")
    file.write(f"D:\"Port\"=0000{hexport}\n")
    file.write(f"S:\"Protocol Name\"=Telnet\n")  # Use telnet protocol
    file.write(f"S:\"Color Scheme\"=Traditional\n")
    file.write(f"D:\"ANSI Color\"=00000001\n")
    file.write(f"S:\"Emulation\"=VT100\n")

key_path = r"SOFTWARE\VanDyke\SecureCRT" # Replace with your specific subkey if needed
try:
    with winreg.OpenKey(winreg.HKEY_CURRENT_USER, key_path) as key:
        # Replace "value_name" with the specific value you want to read within the key
        value_name = "Config Path"
        secureCrtPath, _ = winreg.QueryValueEx(key, value_name)
except WindowsError:
    print(f"Error accessing registry key: {key_path}")
#define folder for labs and sessions to be placed
parent_folder = secureCrtPath + "\sessions\_CML" 
#purge old labs/sessions
os.system(f'rmdir /s /q "{parent_folder}"')

# Specify the YAML file path
yaml_file_path = "labs.yaml"  # Replace with your YAML file path

# Load the YAML data
try:
  with open(yaml_file_path, "r") as file:
    data = yaml.safe_load(file)
    print(f"Successfully loaded YAML data from: {yaml_file_path}")
except FileNotFoundError as e:
  print(f"Error: YAML file not found: {e}")
  exit()
except yaml.YAMLError as e:
  print(f"Error loading YAML data: {e}")
  exit()

# Extract and handle potential missing key
nodes_data = data.get('nodes', {})

# Generate session.ini files and folders
node_info = []
print("Generating SecureCRT session.ini files for each node:")
for item_name, item_data in data.items():
  # Check for 'nodes' key within each top-level item
  if 'nodes' in item_data:
    for node_id, node_data in item_data['nodes'].items():
      label = node_data['label']
      for device in node_data['devices']:
        if device['enabled']:
          port = device['listen_port']
          lab_title = item_data['lab_title']
          filename = f"{label}_{port}.ini"
          valid_chars = " -_.0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
          #sanitize folder and file names
          lab_title = "".join(c for c in lab_title if c in valid_chars) 
          filename = "".join(c for c in filename if c in valid_chars)
          generate_session_ini(label, port, lab_title, filename, parent_folder)
          print(f"- {parent_folder}/{lab_title}/{filename}")
print(f"File Generation Complete, Restart secureCRT if open already.")
