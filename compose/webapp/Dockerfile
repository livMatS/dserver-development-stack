# dtool-lookup-webapp Docker image
# Node.js based container for Vue.js development server
FROM node:20-alpine

# Set working directory
WORKDIR /app

# Copy package files first for better caching
COPY ./dtool-lookup-webapp/dtool-lookup-webapp/package*.json ./

# Install dependencies (use legacy-peer-deps to resolve version conflicts)
RUN npm install --legacy-peer-deps

# Copy the rest of the application
COPY ./dtool-lookup-webapp/dtool-lookup-webapp/ ./

# Create .env file for Vue CLI
# Environment variables starting with VUE_APP_ are passed at runtime
# but we need a placeholder .env for the build process
RUN echo 'VUE_APP_DTOOL_LOOKUP_SERVER_URL=http://localhost:5000' > .env && \
    echo 'VUE_APP_DTOOL_LOOKUP_SERVER_TOKEN_GENERATOR_URL=http://localhost:5001/token' >> .env

# Expose the development server port
EXPOSE 8080

# Default command runs the development server
CMD ["npm", "run", "serve", "--", "--host", "0.0.0.0"]
