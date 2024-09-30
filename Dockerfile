FROM public.ecr.aws/lambda/nodejs20.x

COPY package*.json ./
RUN npm install

COPY . .

CMD ["index.lambdaHandler"]